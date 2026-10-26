import Foundation
import Combine
import CoreLocation
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceLocation
import WakTrainerServiceHealthKit
import WakTrainerFeatureTimer

protocol WorkoutLocationManaging: AnyObject {

    var userLocationPublisher: AnyPublisher<CLLocation?, Never> { get }

    var routeCoordinatesPublisher: AnyPublisher<
        [CLLocationCoordinate2D],
        Never
    > { get }

    var routePointsPublisher: AnyPublisher<
        [WorkoutRoutePoint],
        Never
    > { get }

    func requestLocationPermission()
    func startTracking()
    func stopTracking()
}

extension LocationManager: WorkoutLocationManaging {

    var userLocationPublisher: AnyPublisher<CLLocation?, Never> {
        $userLocation.eraseToAnyPublisher()
    }

    var routeCoordinatesPublisher: AnyPublisher<
        [CLLocationCoordinate2D],
        Never
    > {
        $routeCoordinates.eraseToAnyPublisher()
    }

    var routePointsPublisher: AnyPublisher<
        [WorkoutRoutePoint],
        Never
    > {
        $routePoints.eraseToAnyPublisher()
    }
}

@MainActor
final class WorkoutSessionViewModel: ObservableObject {

    // MARK: - Workout

    let workout: WorkoutDefinition

    // MARK: - Dependencies

    private let healthKitManager: HealthKitManagerProtocol
    private let locationManager: (any WorkoutLocationManaging)?
    private let strengthLocationPolicy: StrengthWorkoutLocationPolicy
    private var didCaptureStrengthLocation = false
    private var snapshotTimeoutTask: Task<Void, Never>?
    private var locationSubscriptions = Set<AnyCancellable>()
    private let sessionRepository: (any WorkoutSessionRepository)?
    private(set) var timerManager: TimerManager
    private let restTimerManager: TimerManager

    // MARK: - Health Data

    @Published private(set) var healthSampleEndDates: [WorkoutHealthMetric: Date] = [:]
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var stepCount: Double = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var healthDataCollectionError: String?
    @Published private(set) var storageError: String?

    // MARK: - Location Data

    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var routePoints: [WorkoutRoutePoint] = []

    // MARK: - Timer Data

    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var laps: [LapItem] = []

    // MARK: - Strength Data

    @Published private(set) var activeStrengthExercise:
        StrengthExerciseDefinition?
    @Published private(set) var activeStrengthEquipment:
        StrengthEquipment?
    @Published private(set) var completedStrengthExerciseRecords:
        [WorkoutExerciseRecord] = []
    @Published private(set) var strengthSets:
        [StrengthSetRecord] = []
    @Published private(set) var isResting = false
    @Published private(set) var restElapsedTime:
        TimeInterval = 0

    private var activeStrengthExerciseStartDate:
        Date?
    private var activeStrengthRecordID = UUID()

    // MARK: - Session State

    private var sessionID = UUID()
    private var sessionStartDate: Date?
    private var completedPauseIntervals: [WorkoutPauseInterval] = []
    private var openPauseStartDate: Date?
    private var recoveredHealthData: WorkoutHealthData?
    private var recoveredActiveCaloriesBase: Double = 0
    private var recoveredStepCountBase: Double = 0
    private var recoveredDistanceBase: Double = 0
    private var recoveryResumeDate: Date?
    private var needsRuntimeRestart = false
    private var restoredRouteCoordinates:
        [CLLocationCoordinate2D] = []
    private var restoredRoutePoints:
        [WorkoutRoutePoint] = []

    // MARK: - Private

    private var healthTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    private var simulator = DebugWorkoutSimulator()
    private var useSimulation: Bool {
#if DEBUG && targetEnvironment(simulator)
        UserDefaults.standard.bool(forKey: "WakTrainer.debug.simulateWorkout")
#else
        false
#endif
    }
    private var checkpointTask: Task<Void, Never>?

    private static let checkpointIntervalNanoseconds: UInt64 =
        15_000_000_000

    // MARK: - Initializer

    init(
        workout: WorkoutDefinition,
        restoredSession: StoredWorkoutSession? = nil,
        healthKitManager:
            HealthKitManagerProtocol = HealthKitManager(),
        locationManager:
            (any WorkoutLocationManaging)? = nil,
        strengthLocationPolicy: StrengthWorkoutLocationPolicy = .singleLocation,
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        timerManager: TimerManager = TimerManager(),
        restTimerManager: TimerManager = TimerManager()
    ) {
        self.workout = workout
        self.strengthLocationPolicy = strengthLocationPolicy
        self.healthKitManager = healthKitManager

        if let locationManager {
            self.locationManager = locationManager
        } else if workout.requiresLocationTracking || (workout.category == .strength && strengthLocationPolicy == .singleLocation) {
            self.locationManager = LocationManager()
        } else {
            self.locationManager = nil
        }

        self.sessionRepository = sessionRepository
        self.timerManager = timerManager
        self.restTimerManager = restTimerManager

        if let restoredSession {
            restorePersistedSession(
                restoredSession
            )
        }

        setupSubscriptions()
    }

    deinit {
        healthTask?.cancel()
        simulationTask?.cancel()
        checkpointTask?.cancel()
        snapshotTimeoutTask?.cancel()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        if let locationManager {
            locationManager.userLocationPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] location in
                    guard let self else { return }
                    self.userLocation = location
                    guard self.workout.category == .strength,
                          self.strengthLocationPolicy == .singleLocation,
                          self.timerState != .idle,
                          !self.didCaptureStrengthLocation,
                          let location, location.horizontalAccuracy >= 0 else { return }
                    self.didCaptureStrengthLocation = true
                    self.snapshotTimeoutTask?.cancel()
                    self.locationManager?.stopTracking()
                }
                .store(in: &locationSubscriptions)

            let routeCoordinatePrefix =
                restoredRouteCoordinates
            let routePointPrefix =
                restoredRoutePoints

            locationManager.routeCoordinatesPublisher
                .map {
                    routeCoordinatePrefix + $0
                }
                .receive(on: DispatchQueue.main)
                .assign(to: &$routeCoordinates)

            locationManager.routePointsPublisher
                .map {
                    routePointPrefix + $0
                }
                .receive(on: DispatchQueue.main)
                .assign(to: &$routePoints)
        }

        timerManager.$elapsedTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$elapsedTime)

        timerManager.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$timerState)

        timerManager.$laps
            .receive(on: DispatchQueue.main)
            .assign(to: &$laps)

        restTimerManager.$elapsedTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$restElapsedTime)
    }

    // MARK: - Workout Actions

    var canStartWorkout: Bool {
        guard workout.category == .strength else {
            return true
        }

        return activeStrengthExercise != nil
            && activeStrengthEquipment != nil
    }

    func startWorkout() async {
        guard timerState == .idle,
              canStartWorkout else {
            return
        }

        resetSessionStateForNewWorkout()
        sessionID = UUID()

        if !useSimulation {
            do {
                let granted = try await healthKitManager.requestAuthorization()
                if !granted {
                    healthDataCollectionError = "HealthKit authorization was not completed. Check Health permissions for WakTrainer."
                }
            } catch {
                healthDataCollectionError = "HealthKit authorization failed: \(error.localizedDescription)"
            }
        }

        if workout.requiresLocationTracking && !useSimulation {
            locationManager?.requestLocationPermission()
        }

        let startDate = Date()
        sessionStartDate = startDate

        if activeStrengthExercise != nil {
            activeStrengthExerciseStartDate =
                startDate
        }

        timerManager.start()

        if workout.requiresLocationTracking && !useSimulation {
            locationManager?.startTracking()
        } else if !useSimulation && workout.category == .strength,
                  strengthLocationPolicy == .singleLocation {
            didCaptureStrengthLocation = false
            locationManager?.requestLocationPermission()
            locationManager?.startTracking()
            snapshotTimeoutTask?.cancel()
            snapshotTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                self?.locationManager?.stopTracking()
            }
        }

        if useSimulation {
            simulator = DebugWorkoutSimulator()
            startSimulation()
        } else {
            startHealthObservation()
        }
        await saveCheckpoint()
        startCheckpointLoop()
    }

    func pauseWorkout() {
        guard timerManager.state == .running else { return }
        openPauseStartDate = Date()
        timerManager.pause()
        simulationTask?.cancel()
        // Keep route capture alive while paused so the original GPS points
        // remain available for a later partial restore.

        if isResting {
            restTimerManager.pause()
        }

        Task {
            await saveCheckpoint()
        }
    }

    func resumeWorkout() {
        guard timerManager.state == .paused || needsRuntimeRestart else { return }
        closeOpenPause(at: Date())
        if needsRuntimeRestart {
            recoveryResumeDate = Date()

            if workout.requiresLocationTracking {
                locationManager?
                    .requestLocationPermission()
                locationManager?
                    .startTracking()
            }

            if useSimulation { startSimulation() } else { startHealthObservation() }
            startCheckpointLoop()
            needsRuntimeRestart = false
        }

        timerManager.start()
        // Tracking was not stopped on pause. Recovery restarts it above.
        if useSimulation { startSimulation() }

        if isResting {
            restTimerManager.start()
        }

        Task {
            await saveCheckpoint()
        }
    }

    func finishWorkout() async -> WorkoutSession {
        checkpointTask?.cancel()
        checkpointTask = nil

        let endDate = Date()
        closeOpenPause(at: endDate)
        let startDate =
            sessionStartDate ?? endDate
        let activeDuration = elapsedTime
        let finalSessionID = sessionID
        let finalRoutePoints = routePoints

        let finalStrengthExerciseRecords =
            strengthExerciseRecordsSnapshot(
                endDate: endDate
            )

        await stopWorkout()

        let healthData: WorkoutHealthData

        if useSimulation {
            healthData = simulator.health
        } else if let recoveredHealthData {
            if let recoveryResumeDate {
                let resumedHealthData =
                    await collectFinalHealthData(
                        from: recoveryResumeDate,
                        to: endDate
                    )

                healthData =
                    mergeRecoveredHealthData(
                        recoveredHealthData,
                        with:
                            resumedHealthData
                    )
            } else {
                healthData =
                    recoveredHealthData
            }
        } else {
            healthData =
                await collectFinalHealthData(
                    from: startDate,
                    to: endDate
                )
        }

        let session = makeSession(
            id: finalSessionID,
            startDate: startDate,
            endDate: endDate,
            activeDuration:
                activeDuration,
            healthData: healthData,
            routePoints:
                finalRoutePoints,
            strengthExerciseRecords:
                finalStrengthExerciseRecords
        )

        do {
            try await sessionRepository?
                .saveCompleted(
                    session
                )
            storageError = nil
        } catch {
            storageError =
                error.localizedDescription
        }

        sessionStartDate = nil

        return session
    }

    private func stopWorkout() async {
        snapshotTimeoutTask?.cancel()
        if workout.requiresLocationTracking || strengthLocationPolicy == .singleLocation {
            locationManager?.stopTracking()
        }
        restTimerManager.stop()
        isResting = false

        timerManager.stop()

        healthTask?.cancel()
        healthTask = nil
        simulationTask?.cancel()
        simulationTask = nil

        await healthKitManager
            .stopObservingData()
    }

    func recordLap() {
        timerManager.recordLap()

        Task {
            await saveCheckpoint()
        }
    }

    // MARK: - Strength Exercise Flow

    @discardableResult
    func beginStrengthExercise(
        _ exercise:
            StrengthExerciseDefinition,
        equipment:
            StrengthEquipment
    ) -> Bool {
        guard workout.category == .strength,
              exercise.supportedEquipment
                .contains(equipment) else {
            return false
        }

        if activeStrengthExercise != nil {
            if !strengthSets.isEmpty {
                finishCurrentStrengthExerciseInternal(
                    endDate: Date()
                )
            } else {
                clearActiveStrengthExercise()
            }
        }

        restTimerManager.stop()
        isResting = false

        // Returning to a previously used exercise continues its existing sets
        // rather than creating another record for the same superset movement.
        if let index = completedStrengthExerciseRecords.firstIndex(where: {
            $0.exerciseID == exercise.id && $0.strengthEquipment == equipment
        }) {
            let previous = completedStrengthExerciseRecords.remove(at: index)
            activeStrengthRecordID = previous.id
            activeStrengthExerciseStartDate = previous.startDate
            strengthSets = previous.strengthSets
        } else {
            activeStrengthRecordID = UUID()
            activeStrengthExerciseStartDate = timerState == .idle ? nil : Date()
            strengthSets = []
        }

        activeStrengthExercise =
            exercise
        activeStrengthEquipment =
            equipment

        if timerState != .idle {
            Task {
                await saveCheckpoint()
            }
        }

        return true
    }

    @discardableResult
    func finishCurrentStrengthExercise()
        -> Bool {
        guard workout.category == .strength,
              activeStrengthExercise != nil,
              !strengthSets.isEmpty else {
            return false
        }

        finishCurrentStrengthExerciseInternal(
            endDate: Date()
        )

        Task {
            await saveCheckpoint()
        }

        return true
    }

    @discardableResult
    func recordStrengthSet(
        weightKilograms: Double?,
        repetitions: Int,
        isWarmup: Bool = false,
        startRest: Bool = false
    ) -> Bool {
        guard workout.category == .strength,
              timerManager.isRunning,
              !isResting,
              activeStrengthExercise != nil,
              let equipment =
                activeStrengthEquipment,
              repetitions > 0 else {
            return false
        }

        let normalizedWeight:
            Double?

        if equipment.requiresWeightInput {
            guard let weightKilograms,
                  weightKilograms > 0 else {
                return false
            }

            normalizedWeight =
                weightKilograms
        } else {
            normalizedWeight = nil
        }

        strengthSets.append(
            StrengthSetRecord(
                setNumber:
                    strengthSets.count + 1,
                weightKilograms:
                    normalizedWeight,
                repetitions:
                    repetitions,
                endDate: Date(),
                isWarmup: isWarmup,
                isCompleted: true
            )
        )

        restTimerManager.stop()
        if startRest {
            restTimerManager.start()
        }
        isResting = startRest

        Task {
            await saveCheckpoint()
        }

        return true
    }

    @discardableResult
    func updateStrengthSet(
        id: UUID,
        weightKilograms: Double?,
        repetitions: Int,
        isWarmup: Bool
    ) -> Bool {
        guard workout.category == .strength,
              timerState != .idle,
              let equipment = activeStrengthEquipment,
              let index = strengthSets.firstIndex(where: { $0.id == id }),
              repetitions > 0 else {
            return false
        }

        if equipment.requiresWeightInput {
            guard let weightKilograms, weightKilograms > 0,
                  weightKilograms.isFinite else { return false }
            strengthSets[index].weightKilograms = weightKilograms
        } else {
            strengthSets[index].weightKilograms = nil
        }
        strengthSets[index].repetitions = repetitions
        strengthSets[index].isWarmup = isWarmup

        Task { await saveCheckpoint() }
        return true
    }

    @discardableResult
    func finishRestAndStartNextSet()
        -> Bool {
        guard workout.category == .strength,
              isResting,
              !strengthSets.isEmpty else {
            return false
        }

        let completedRestDuration =
            restTimerManager.elapsedTime

        restTimerManager.stop()

        strengthSets[
            strengthSets.index(
                before:
                    strengthSets.endIndex
            )
        ].restDuration =
            completedRestDuration

        isResting = false

        Task {
            await saveCheckpoint()
        }

        return true
    }

    var nextStrengthSetNumber: Int {
        strengthSets.count + 1
    }

    var lastStrengthSet:
        StrengthSetRecord? {
        strengthSets.last
    }

    var hasStrengthExerciseHistory: Bool {
        !completedStrengthExerciseRecords
            .isEmpty
    }

    private func finishCurrentStrengthExerciseInternal(
        endDate: Date
    ) {
        guard let exercise =
                activeStrengthExercise,
              !strengthSets.isEmpty else {
            clearActiveStrengthExercise()
            return
        }

        restTimerManager.stop()
        isResting = false

        completedStrengthExerciseRecords
            .append(
                WorkoutExerciseRecord(
                    exerciseID:
                        exercise.id,
                    name:
                        exercise.name,
                    kind: .strength,
                    strengthEquipment:
                        activeStrengthEquipment,
                    startDate:
                        activeStrengthExerciseStartDate
                        ?? sessionStartDate
                        ?? endDate,
                    endDate: endDate,
                    strengthSets:
                        strengthSets
                )
            )

        clearActiveStrengthExercise()
    }

    private func clearActiveStrengthExercise() {
        restTimerManager.stop()
        isResting = false
        activeStrengthExercise = nil
        activeStrengthEquipment = nil
        activeStrengthExerciseStartDate = nil
        activeStrengthRecordID = UUID()
        strengthSets = []
    }

    private func resetSessionStateForNewWorkout() {
        completedPauseIntervals = []
        openPauseStartDate = nil
        healthDataCollectionError = nil
        storageError = nil
        healthSampleEndDates = [:]

        restTimerManager.stop()
        isResting = false

        completedStrengthExerciseRecords
            .removeAll()
        strengthSets.removeAll()
        activeStrengthExerciseStartDate = nil
    }

    // MARK: - Simulator-only measurements

    private func startSimulation() {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard self.timerState == .running else { continue }
                self.simulator.advance(
                    at: Date(), category: self.workout.category.rawValue,
                    workoutID: self.workout.id
                )
                self.heartRate = self.simulator.heartRate
                self.activeCalories = self.simulator.calories
                self.stepCount = self.simulator.steps
                self.distanceMeters = self.simulator.distance
                self.routePoints = self.simulator.route
                self.routeCoordinates = self.simulator.route.map(\.coordinate)

                // Populate actual exercise records through the existing set recorder.
                // A selected strength exercise is required by the production UI.
                if self.workout.category == .strength,
                   Int(self.simulator.seconds) % 25 == 0 {
                    if self.isResting {
                        _ = self.finishRestAndStartNextSet()
                    } else if let equipment = self.activeStrengthEquipment {
                        _ = self.recordStrengthSet(
                            weightKilograms: equipment.requiresWeightInput ? 20 : nil,
                            repetitions: 10
                        )
                    }
                }
            }
        }
    }

    // MARK: - Checkpoint Persistence

    private func startCheckpointLoop() {
        checkpointTask?.cancel()

        checkpointTask = Task {
            [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds:
                            Self
                                .checkpointIntervalNanoseconds
                    )
                } catch {
                    break
                }

                guard !Task.isCancelled else {
                    break
                }

                await self?
                    .saveCheckpoint()
            }
        }
    }

    private func saveCheckpoint() async {
        guard let sessionRepository,
              let startDate =
                sessionStartDate else {
            return
        }

        let liveHealthData = useSimulation ? simulator.health : WorkoutHealthData(
                summary:
                    WorkoutHealthSummary(
                        averageHeartRate:
                            nonZero(
                                heartRate
                            ),
                        activeCalories:
                            nonZero(
                                activeCalories
                            ),
                        stepCount:
                            nonZero(
                                stepCount
                            ),
                        distanceMeters:
                            nonZero(
                                distanceMeters
                            )
                    )
            )

        let checkpoint = makeSession(
            id: sessionID,
            startDate: startDate,
            endDate: nil,
            activeDuration:
                elapsedTime,
            healthData:
                liveHealthData,
            routePoints:
                routePoints,
            strengthExerciseRecords:
                strengthExerciseRecordsSnapshot(
                    endDate: nil
                )
        )

        do {
            try await sessionRepository
                .saveCheckpoint(
                    checkpoint
                )
            storageError = nil
        } catch {
            storageError =
                error.localizedDescription
        }
    }

    // MARK: - Recovery

    private func restorePersistedSession(
        _ storedSession:
            StoredWorkoutSession
    ) {
        let session =
            storedSession.session
        let healthSummary =
            session.health.summary

        sessionID = session.id
        sessionStartDate =
            session.timing.startDate
        completedPauseIntervals = session.timing.pauseIntervals
        openPauseStartDate = nil
        recoveredHealthData =
            session.health

        recoveredActiveCaloriesBase =
            healthSummary.activeCalories
            ?? 0
        recoveredStepCountBase =
            healthSummary.stepCount
            ?? 0
        recoveredDistanceBase =
            healthSummary.distanceMeters
            ?? 0

        heartRate =
            healthSummary.averageHeartRate
            ?? 0
        activeCalories =
            recoveredActiveCaloriesBase
        stepCount =
            recoveredStepCountBase
        distanceMeters =
            recoveredDistanceBase

        restoreStrengthExerciseRecords(
            from:
                session.exerciseRecords
        )

        restoredRoutePoints =
            session.route
        restoredRouteCoordinates =
            session.route.map {
                CLLocationCoordinate2D(
                    latitude:
                        $0.latitude,
                    longitude:
                        $0.longitude
                )
            }

        routePoints =
            restoredRoutePoints
        routeCoordinates =
            restoredRouteCoordinates

        // A checkpoint stores active time only up to its last write.
        // Recover wall-clock time since the workout began, excluding
        // explicit recorded pauses. Otherwise a process termination loses
        // all workout time after the last checkpoint.
        let now = Date()
        let wallDuration = max(0, now.timeIntervalSince(session.timing.startDate))
        let recordedPauseDuration = session.timing.pauseIntervals.reduce(0.0) {
            total, interval in
            total + max(0, interval.endDate.timeIntervalSince(interval.startDate))
        }
        // Do not extrapolate stale/legacy sessions indefinitely.
        // A checkpoint taken during a pause has a trailing pause interval
        // ending at its save time; keep the timer stopped in that case.
        let checkpointAge = now.timeIntervalSince(storedSession.updatedAt)
        let recentlyCheckpointed = checkpointAge >= 0 && checkpointAge <= 12 * 3600
        let wasPausedAtCheckpoint = session.timing.pauseIntervals.last.map {
            abs($0.endDate.timeIntervalSince(storedSession.updatedAt)) <= 2
        } ?? false
        let recoveredDuration: TimeInterval
        if recentlyCheckpointed && !wasPausedAtCheckpoint {
            recoveredDuration = min(
                wallDuration,
                max(session.timing.activeDuration, wallDuration - recordedPauseDuration)
            )
        } else {
            recoveredDuration = session.timing.activeDuration
        }
        timerManager.restore(elapsedTime: recoveredDuration)

        elapsedTime =
            timerManager.elapsedTime
        timerState =
            timerManager.state
        laps =
            timerManager.laps

        needsRuntimeRestart = true
    }

    private func restoreStrengthExerciseRecords(
        from records:
            [WorkoutExerciseRecord]
    ) {
        guard workout.category
            == .strength else {
            return
        }

        let strengthRecords =
            records.filter {
                $0.kind == .strength
            }

        completedStrengthExerciseRecords =
            strengthRecords.filter {
                $0.endDate != nil
            }

        guard let activeRecord =
                strengthRecords.last(
                    where: {
                        $0.endDate == nil
                    }
                ) else {
            return
        }

        let supportedEquipment:
            [StrengthEquipment]

        if let equipment =
                activeRecord
                    .strengthEquipment {
            supportedEquipment = [
                equipment
            ]
        } else {
            supportedEquipment =
                StrengthEquipment.allCases
        }

        activeStrengthExercise =
            StrengthExerciseDefinition(
                id:
                    activeRecord
                        .exerciseID
                    ?? activeRecord.name,
                name:
                    activeRecord.name,
                supportedEquipment:
                    supportedEquipment
            )
        activeStrengthEquipment =
            activeRecord
                .strengthEquipment
        activeStrengthExerciseStartDate =
            activeRecord.startDate
        activeStrengthRecordID = activeRecord.id
        strengthSets =
            activeRecord.strengthSets
    }

    // MARK: - Health Observation

    private func startHealthObservation() {
        healthTask?.cancel()

        healthTask = Task {
            [weak self] in
            guard let self else {
                return
            }

            let stream =
                healthKitManager
                    .startObservingData()

            for await snapshot in stream {
                guard !Task.isCancelled else {
                    break
                }

                self.healthSampleEndDates = snapshot.sampleEndDates
                self.heartRate =
                    snapshot.heartRate
                self.activeCalories =
                    self
                        .recoveredActiveCaloriesBase
                    + snapshot.activeCalories
                self.stepCount =
                    self
                        .recoveredStepCountBase
                    + snapshot.stepCount
                self.distanceMeters =
                    self
                        .recoveredDistanceBase
                    + snapshot.distance
            }
        }
    }

    private func collectFinalHealthData(
        from startDate: Date,
        to endDate: Date
    ) async -> WorkoutHealthData {
        do {
            return try await healthKitManager.fetchWorkoutHealthData(
                from: startDate,
                to: endDate
            )
        } catch {
            healthDataCollectionError = error.localizedDescription
            return WorkoutHealthData()
        }
    }

    private func mergeRecoveredHealthData(
        _ recovered:
            WorkoutHealthData,
        with resumed:
            WorkoutHealthData
    ) -> WorkoutHealthData {
        var merged = resumed
        let previous =
            recovered.summary

        merged.summary.activeCalories = sumOptional(
            previous.activeCalories,
            resumed.summary.activeCalories
        )

        merged.summary.stepCount = sumOptional(
            previous.stepCount,
            resumed.summary.stepCount
        )

        merged.summary.distanceMeters = sumOptional(
            previous.distanceMeters,
            resumed.summary.distanceMeters
        )

        if merged.summary
            .averageHeartRate == nil {
            merged.summary
                .averageHeartRate =
                previous
                    .averageHeartRate
        }

        merged.summary
            .minimumHeartRate =
            minimumOptional(
                previous
                    .minimumHeartRate,
                resumed.summary
                    .minimumHeartRate
            )

        merged.summary
            .maximumHeartRate =
            maximumOptional(
                previous
                    .maximumHeartRate,
                resumed.summary
                    .maximumHeartRate
            )

        merged.samples =
            recovered.samples
            + resumed.samples

        return merged
    }

    private func sumOptional(
        _ lhs: Double?,
        _ rhs: Double?
    ) -> Double? {
        guard lhs != nil || rhs != nil else {
            return nil
        }
        return (lhs ?? 0) + (rhs ?? 0)
    }

    private func minimumOptional(
        _ lhs: Double?,
        _ rhs: Double?
    ) -> Double? {
        switch (lhs, rhs) {
        case let (
            .some(lhs),
            .some(rhs)
        ):
            min(lhs, rhs)

        case let (
            .some(value),
            .none
        ),
        let (
            .none,
            .some(value)
        ):
            value

        case (.none, .none):
            nil
        }
    }

    private func maximumOptional(
        _ lhs: Double?,
        _ rhs: Double?
    ) -> Double? {
        switch (lhs, rhs) {
        case let (
            .some(lhs),
            .some(rhs)
        ):
            max(lhs, rhs)

        case let (
            .some(value),
            .none
        ),
        let (
            .none,
            .some(value)
        ):
            value

        case (.none, .none):
            nil
        }
    }

    private func nonZero(
        _ value: Double
    ) -> Double? {
        value > 0
            ? value
            : nil
    }

    // MARK: - Session

    private func closeOpenPause(at endDate: Date) {
        guard let startDate = openPauseStartDate else { return }
        openPauseStartDate = nil
        guard endDate > startDate else { return }
        completedPauseIntervals.append(
            WorkoutPauseInterval(startDate: startDate, endDate: endDate)
        )
    }

    private func strengthExerciseRecordsSnapshot(
        endDate: Date?
    ) -> [WorkoutExerciseRecord] {
        var records =
            completedStrengthExerciseRecords

        guard let exercise =
                activeStrengthExercise,
              !strengthSets.isEmpty else {
            return records
        }

        records.append(
            WorkoutExerciseRecord(
                id: activeStrengthRecordID,
                exerciseID:
                    exercise.id,
                name:
                    exercise.name,
                kind: .strength,
                strengthEquipment:
                    activeStrengthEquipment,
                startDate:
                    activeStrengthExerciseStartDate
                    ?? sessionStartDate
                    ?? endDate
                    ?? Date(),
                endDate: endDate,
                strengthSets:
                    strengthSets
            )
        )

        return records
    }

    private func makeSession(
        id: UUID,
        startDate: Date,
        endDate: Date?,
        activeDuration: TimeInterval,
        healthData:
            WorkoutHealthData,
        routePoints:
            [WorkoutRoutePoint],
        strengthExerciseRecords:
            [WorkoutExerciseRecord]
    ) -> WorkoutSession {
        let referenceDate =
            endDate ?? Date()

        let elapsedDuration =
            max(
                0,
                referenceDate
                    .timeIntervalSince(
                        startDate
                    )
            )

        let normalizedActiveDuration =
            min(
                max(
                    0,
                    activeDuration
                ),
                elapsedDuration
            )

        let timing =
            WorkoutTiming(
                startDate: startDate,
                endDate: endDate,
                elapsedDuration:
                    elapsedDuration,
                activeDuration:
                    normalizedActiveDuration,
                pausedDuration:
                    max(
                        0,
                        elapsedDuration
                        - normalizedActiveDuration
                    ),
                pauseIntervals: completedPauseIntervals + (openPauseStartDate.map { start in
                    [WorkoutPauseInterval(startDate: start, endDate: referenceDate)]
                } ?? [])
            )

        let identity =
            WorkoutIdentity(
                workoutID:
                    workout.id,
                name:
                    workout.name,
                category:
                    workout.category
                        .rawValue,
                type:
                    workout.type
            )

        let exerciseRecords:
            [WorkoutExerciseRecord]

        if workout.category
            == .strength {
            exerciseRecords =
                strengthExerciseRecords
        } else {
            exerciseRecords = [
                WorkoutExerciseRecord(
                    exerciseID:
                        workout.id,
                    name:
                        workout.name,
                    kind: .cardio,
                    startDate:
                        startDate,
                    endDate:
                        endDate
                )
            ]
        }

        return WorkoutSession(
            id: id,
            workout: identity,
            timing: timing,
            exerciseRecords:
                exerciseRecords,
            health: healthData,
            route: routePoints
        )
    }

    // MARK: - UI Values

    var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
}
