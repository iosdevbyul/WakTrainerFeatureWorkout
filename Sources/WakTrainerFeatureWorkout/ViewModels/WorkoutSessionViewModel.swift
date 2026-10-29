import Foundation
import Combine
import CoreLocation
import TrisMotionKit
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
    private var capturedStrengthLocation: WorkoutRoutePoint?
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
    private var lastPersistedHealthQueryEnd: Date?
    private var recoveredActiveCaloriesBase: Double = 0
    private var recoveredStepCountBase: Double = 0
    private var recoveredDistanceBase: Double = 0
    private var recoveryResumeDate: Date?
    private var needsRuntimeRestart = false
    private var shouldAutoResumeRecoveredSession = false
    private var restoredRouteCoordinates:
        [CLLocationCoordinate2D] = []
    private var restoredRoutePoints:
        [WorkoutRoutePoint] = []

    // MARK: - Private

    private var healthTask: Task<Void, Never>?
    private var externalHeartRateTask: Task<Void, Never>?
    private var externalHeartRateSession: AnyObject?
    private var externalHeartRateLatest: Double?
    private let pedometer: any PedometerServing = PedometerService()
    private var externalHeartRateSamples: [WorkoutHealthMetricSample] = []
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
        externalHeartRateTask?.cancel()
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
                    self.capturedStrengthLocation = WorkoutRoutePoint(
                        timestamp: location.timestamp,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        altitude: location.altitude,
                        horizontalAccuracy: location.horizontalAccuracy
                    )
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
            if #available(iOS 26.0, *) {
                if healthKitManager is HealthKitManager {
                    let requestedID = sessionID
                    Task { [weak self] in
                        await self?.startExternalHeartRate(for: requestedID)
                    }
                }
            }
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

            if useSimulation {
                startSimulation()
            } else {
                startHealthObservation()
                if #available(iOS 26.0, *), healthKitManager is HealthKitManager {
                    let requestedID = sessionID
                    Task { [weak self] in
                        await self?.startExternalHeartRate(for: requestedID)
                    }
                }
            }
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
        let finalRoutePoints: [WorkoutRoutePoint] =
            workout.category == .strength && strengthLocationPolicy == .singleLocation
                ? (capturedStrengthLocation.map { [$0] } ?? routePoints)
                : routePoints

        let finalStrengthExerciseRecords =
            strengthExerciseRecordsSnapshot(
                endDate: endDate
            )

        await stopWorkout()

        let healthData: WorkoutHealthData

        if useSimulation {
            healthData = simulator.health
        } else {
            // Query the complete workout span, not only the resumed portion.
            // HealthKit can retain samples from before the app was terminated.
            let complete = await collectFinalHealthData(
                from: startDate, to: endDate
            )
            if let recoveredHealthData {
                healthData = mergeRecoveredHealthData(
                    recoveredHealthData, with: complete
                )
            } else {
                healthData = complete
            }
        }

        // Include external BPM observations that may not be written to HealthKit.
        var completeHealthData = healthData
        completeHealthData.samples = mergeHealthSamples(
            completeHealthData.samples, externalHeartRateSamples
        )
        if !useSimulation, let motionSample = await queryCoreMotionStepCount(
            from: startDate, to: endDate
        ) {
            completeHealthData.samples = mergeHealthSamples(
                completeHealthData.samples, [motionSample]
            )
            // Summary is what WorkoutReportBuilder renders. Store both
            // sources in samples, but use the complete Core Motion interval
            // as the representative count when available.
            if motionSample.value > 0 {
                completeHealthData.summary.stepCount = motionSample.value
            }
        }

        let session = makeSession(
            id: finalSessionID,
            startDate: startDate,
            endDate: endDate,
            activeDuration:
                activeDuration,
            healthData: completeHealthData,
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

        if #available(iOS 26.0, *) {
            await stopExternalHeartRate()
        }
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
        externalHeartRateLatest = nil

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

        // Persist timestamped HealthKit samples as well as live summary values.
        // A summary-only checkpoint cannot reconstruct the pre-relaunch HR chart.
        let liveHealthData: WorkoutHealthData
        let checkpointQueryEnd = Date()
        if useSimulation {
            liveHealthData = simulator.health
        } else {
            let queryEnd = checkpointQueryEnd
            // Keep a short overlap for slightly delayed HealthKit samples.
            // Only advance the cursor after the checkpoint has been saved.
            let queryStart = max(
                startDate,
                (lastPersistedHealthQueryEnd ?? startDate).addingTimeInterval(-60)
            )
            let measured = await collectFinalHealthData(from: queryStart, to: queryEnd)
            var checkpointHealth = measured
            checkpointHealth.summary.activeCalories = nonZero(activeCalories)
            checkpointHealth.summary.stepCount = nonZero(stepCount)
            checkpointHealth.summary.distanceMeters = nonZero(distanceMeters)
            if checkpointHealth.summary.averageHeartRate == nil {
                checkpointHealth.summary.averageHeartRate = nonZero(heartRate)
            }
            // A partial HealthKit response may contain some new samples but
            // omit the pre-relaunch interval. Always retain the persisted
            // history, even when the new query is nonempty.
            if let recoveredHealthData {
                checkpointHealth.samples = mergeHealthSamples(
                    recoveredHealthData.samples,
                    checkpointHealth.samples
                )
            }
            checkpointHealth.samples = mergeHealthSamples(
                checkpointHealth.samples, externalHeartRateSamples
            )
            if let motionSample = await queryCoreMotionStepCount(
                from: startDate, to: checkpointQueryEnd
            ) {
                checkpointHealth.samples = mergeHealthSamples(
                    checkpointHealth.samples, [motionSample]
                )
                if motionSample.value > 0 {
                    checkpointHealth.summary.stepCount = motionSample.value
                }
            }
            liveHealthData = checkpointHealth
        }

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
            // Carry forward successfully persisted samples across subsequent
            // checkpoints, including additional app relaunches.
            recoveredHealthData = liveHealthData
            if !useSimulation {
                lastPersistedHealthQueryEnd = checkpointQueryEnd
            }
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
        externalHeartRateSamples = session.health.samples.filter {
            $0.metric == .heartRate && $0.sourceName == "External Heart Rate"
        }
        // Re-query the final minute of the restored session; retain all
        // previously checkpointed samples even if HealthKit returns a subset.
        lastPersistedHealthQueryEnd = session.health.samples
            .map(\.endDate)
            .max()

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
        // TimerManager.restore intentionally restores to .paused.
        // Only restart sessions that were running at their last checkpoint.
        shouldAutoResumeRecoveredSession = recentlyCheckpointed && !wasPausedAtCheckpoint
    }

    func resumeRecoveredWorkoutIfNeeded() {
        guard shouldAutoResumeRecoveredSession else { return }
        shouldAutoResumeRecoveredSession = false
        resumeWorkout()
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

    // MARK: - External iPhone heart rate (AirPods Pro 3 / iOS 26+)

    @available(iOS 26.0, *)
    private func startExternalHeartRate(for requestedID: UUID) async {
        guard !useSimulation,
              timerState != .idle,
              requestedID == sessionID,
              externalHeartRateSession == nil else { return }
        let collector = ExternalHeartRateWorkoutSession()
        externalHeartRateSession = collector
        do {
            let stream = try await collector.start()
            guard requestedID == sessionID, timerState != .idle else {
                try? await collector.stop()
                if externalHeartRateSession === collector {
                    externalHeartRateSession = nil
                }
                return
            }
            externalHeartRateTask?.cancel()
            externalHeartRateTask = Task { [weak self] in
                for await bpm in stream {
                    guard !Task.isCancelled, let self else { break }
                    guard self.sessionID == requestedID,
                          self.externalHeartRateSession === collector else { break }
                    self.externalHeartRateLatest = bpm
                    self.heartRate = bpm
                    guard bpm.isFinite, bpm > 0 else { continue }
                    let measuredAt = Date()
                    self.externalHeartRateSamples.append(
                        WorkoutHealthMetricSample(
                            metric: .heartRate,
                            startDate: measuredAt,
                            endDate: measuredAt,
                            value: bpm,
                            unit: "count/min",
                            sourceName: "External Heart Rate"
                        )
                    )
                }
            }
        } catch {
            if externalHeartRateSession === collector {
                externalHeartRateSession = nil
            }
            // An unavailable sensor must never prevent a workout from starting.
            healthDataCollectionError = "External heart rate unavailable: \(error.localizedDescription)"
        }
    }

    @available(iOS 26.0, *)
    private func stopExternalHeartRate() async {
        externalHeartRateTask?.cancel()
        externalHeartRateTask = nil
        externalHeartRateLatest = nil
        guard let collector = externalHeartRateSession as? ExternalHeartRateWorkoutSession else {
            externalHeartRateSession = nil
            return
        }
        externalHeartRateSession = nil
        do {
            try await collector.stop()
        } catch {
            healthDataCollectionError = "External heart rate session could not finish: \(error.localizedDescription)"
        }
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
                    self.externalHeartRateLatest ?? snapshot.heartRate
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
        _ recovered: WorkoutHealthData,
        with complete: WorkoutHealthData
    ) -> WorkoutHealthData {
        // The new fetch spans the entire workout, so its totals must NOT be
        // added to checkpoint totals. Retain old values only when unavailable.
        var merged = complete
        if merged.summary.averageHeartRate == nil {
            merged.summary.averageHeartRate = recovered.summary.averageHeartRate
        }
        if merged.summary.activeCalories == nil {
            merged.summary.activeCalories = recovered.summary.activeCalories
        }
        if merged.summary.stepCount == nil {
            merged.summary.stepCount = recovered.summary.stepCount
        }
        if merged.summary.distanceMeters == nil {
            merged.summary.distanceMeters = recovered.summary.distanceMeters
        }
        merged.summary.minimumHeartRate = minimumOptional(
            recovered.summary.minimumHeartRate, complete.summary.minimumHeartRate
        )
        merged.summary.maximumHeartRate = maximumOptional(
            recovered.summary.maximumHeartRate, complete.summary.maximumHeartRate
        )

        merged.samples = mergeHealthSamples(recovered.samples, complete.samples)
        return merged
    }

    // Preserve Core Motion measurements separately from HealthKit samples.
    private func queryCoreMotionStepCount(
        from startDate: Date, to endDate: Date
    ) async -> WorkoutHealthMetricSample? {
        do {
            guard let data = try await pedometer.steps(
                from: startDate, to: endDate
            ) else { return nil }
            return WorkoutHealthMetricSample(
                metric: .stepCount,
                startDate: data.startDate,
                endDate: data.endDate,
                value: Double(data.steps),
                unit: "count",
                sourceName: "Core Motion",
                sourceBundleIdentifier: Bundle.main.bundleIdentifier
            )
        } catch {
            return nil
        }
    }

    private func mergeHealthSamples(
        _ previous: [WorkoutHealthMetricSample],
        _ current: [WorkoutHealthMetricSample]
    ) -> [WorkoutHealthMetricSample] {
        var seen = Set<String>()
        return (previous + current)
            .filter { sample in
                let key = [
                    sample.metric.rawValue,
                    String(sample.startDate.timeIntervalSince1970),
                    String(sample.endDate.timeIntervalSince1970),
                    String(sample.value),
                    sample.unit,
                    sample.sourceBundleIdentifier ?? "",
                    sample.sourceName ?? ""
                ].joined(separator: "|")
                return seen.insert(key).inserted
            }
            .sorted { $0.startDate < $1.startDate }
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
