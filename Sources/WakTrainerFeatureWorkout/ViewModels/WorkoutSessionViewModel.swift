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
    private let sessionRepository: (any WorkoutSessionRepository)?
    private(set) var timerManager: TimerManager
    private let restTimerManager: TimerManager

    // MARK: - Health Data

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

    // MARK: - Session State

    private var sessionID = UUID()
    private var sessionStartDate: Date?
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
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        timerManager: TimerManager = TimerManager(),
        restTimerManager: TimerManager = TimerManager()
    ) {
        self.workout = workout
        self.healthKitManager = healthKitManager

        if let locationManager {
            self.locationManager = locationManager
        } else if workout.requiresLocationTracking {
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
        checkpointTask?.cancel()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        if let locationManager {
            locationManager.userLocationPublisher
                .receive(on: DispatchQueue.main)
                .assign(to: &$userLocation)

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

        _ = try? await healthKitManager
            .requestAuthorization()

        if workout.requiresLocationTracking {
            locationManager?
                .requestLocationPermission()
        }

        let startDate = Date()
        sessionStartDate = startDate

        if activeStrengthExercise != nil {
            activeStrengthExerciseStartDate =
                startDate
        }

        timerManager.start()

        if workout.requiresLocationTracking {
            locationManager?.startTracking()
        }

        startHealthObservation()
        await saveCheckpoint()
        startCheckpointLoop()
    }

    func pauseWorkout() {
        timerManager.pause()

        if isResting {
            restTimerManager.pause()
        }

        Task {
            await saveCheckpoint()
        }
    }

    func resumeWorkout() {
        if needsRuntimeRestart {
            recoveryResumeDate = Date()

            if workout.requiresLocationTracking {
                locationManager?
                    .requestLocationPermission()
                locationManager?
                    .startTracking()
            }

            startHealthObservation()
            startCheckpointLoop()
            needsRuntimeRestart = false
        }

        timerManager.start()

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
        let startDate =
            sessionStartDate ?? endDate
        let activeDuration = elapsedTime
        let finalSessionID = sessionID
        let finalRoutePoints = routePoints

        let finalStrengthExerciseRecords =
            strengthExerciseRecordsSnapshot(
                endDate: endDate
            )

        let liveActiveCalories =
            activeCalories
        let liveStepCount = stepCount
        let liveDistance = distanceMeters

        await stopWorkout()

        let healthData: WorkoutHealthData

        if let recoveredHealthData {
            if let recoveryResumeDate {
                let resumedHealthData =
                    await collectFinalHealthData(
                        from:
                            recoveryResumeDate,
                        to: endDate,
                        liveActiveCalories:
                            max(
                                0,
                                liveActiveCalories
                                - recoveredActiveCaloriesBase
                            ),
                        liveStepCount:
                            max(
                                0,
                                liveStepCount
                                - recoveredStepCountBase
                            ),
                        liveDistance:
                            max(
                                0,
                                liveDistance
                                - recoveredDistanceBase
                            )
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
                    to: endDate,
                    liveActiveCalories:
                        liveActiveCalories,
                    liveStepCount:
                        liveStepCount,
                    liveDistance:
                        liveDistance
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
        restTimerManager.stop()
        isResting = false

        timerManager.stop()

        if workout.requiresLocationTracking {
            locationManager?.stopTracking()
        }

        healthTask?.cancel()
        healthTask = nil

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

        activeStrengthExercise =
            exercise
        activeStrengthEquipment =
            equipment
        activeStrengthExerciseStartDate =
            timerState == .idle
                ? nil
                : Date()
        strengthSets = []

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
        isWarmup: Bool = false
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
        restTimerManager.start()
        isResting = true

        Task {
            await saveCheckpoint()
        }

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
        strengthSets = []
    }

    private func resetSessionStateForNewWorkout() {
        healthDataCollectionError = nil
        storageError = nil

        restTimerManager.stop()
        isResting = false

        completedStrengthExerciseRecords
            .removeAll()
        strengthSets.removeAll()
        activeStrengthExerciseStartDate = nil
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

        let liveHealthData =
            WorkoutHealthData(
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

        timerManager.restore(
            elapsedTime:
                session.timing
                    .activeDuration
        )

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
        to endDate: Date,
        liveActiveCalories: Double,
        liveStepCount: Double,
        liveDistance: Double
    ) async -> WorkoutHealthData {
        do {
            var healthData =
                try await healthKitManager
                    .fetchWorkoutHealthData(
                        from: startDate,
                        to: endDate
                    )

            mergeLiveTotals(
                into: &healthData,
                activeCalories:
                    liveActiveCalories,
                stepCount:
                    liveStepCount,
                distance:
                    liveDistance
            )

            return healthData
        } catch {
            healthDataCollectionError =
                error.localizedDescription

            return WorkoutHealthData(
                summary:
                    WorkoutHealthSummary(
                        activeCalories:
                            nonZero(
                                liveActiveCalories
                            ),
                        stepCount:
                            nonZero(
                                liveStepCount
                            ),
                        distanceMeters:
                            nonZero(
                                liveDistance
                            )
                    )
            )
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

        merged.summary.activeCalories =
            (previous.activeCalories
             ?? 0)
            + (resumed.summary
                .activeCalories
               ?? 0)

        merged.summary.stepCount =
            (previous.stepCount
             ?? 0)
            + (resumed.summary
                .stepCount
               ?? 0)

        merged.summary.distanceMeters =
            (previous.distanceMeters
             ?? 0)
            + (resumed.summary
                .distanceMeters
               ?? 0)

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

    private func mergeLiveTotals(
        into healthData:
            inout WorkoutHealthData,
        activeCalories: Double,
        stepCount: Double,
        distance: Double
    ) {
        if healthData.summary
            .activeCalories == nil {
            healthData.summary
                .activeCalories =
                nonZero(
                    activeCalories
                )
        }

        if healthData.summary
            .stepCount == nil {
            healthData.summary
                .stepCount =
                nonZero(
                    stepCount
                )
        }

        if healthData.summary
            .distanceMeters == nil {
            healthData.summary
                .distanceMeters =
                nonZero(
                    distance
                )
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
                    )
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
