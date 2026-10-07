import Foundation
import Combine
import CoreLocation
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceLocation
import WakTrainerServiceHealthKit
import WakTrainerServiceWorkoutStorage
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

    @Published private(set) var strengthSets: [StrengthSetRecord] = []
    @Published private(set) var isResting = false
    @Published private(set) var restElapsedTime: TimeInterval = 0

    // MARK: - Session State

    private var sessionID = UUID()
    private var sessionStartDate: Date?

    // MARK: - Private

    private var healthTask: Task<Void, Never>?
    private var checkpointTask: Task<Void, Never>?

    private static let checkpointIntervalNanoseconds: UInt64 =
        15_000_000_000

    // MARK: - Initializer

    init(
        workout: WorkoutDefinition,
        healthKitManager: HealthKitManagerProtocol = HealthKitManager(),
        locationManager: (any WorkoutLocationManaging)? = nil,
        sessionRepository: (any WorkoutSessionRepository)? = nil,
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

        if let sessionRepository {
            self.sessionRepository = sessionRepository
        } else {
            self.sessionRepository = try? SwiftDataWorkoutSessionRepository()
        }

        self.timerManager = timerManager
        self.restTimerManager = restTimerManager

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

            locationManager.routeCoordinatesPublisher
                .receive(on: DispatchQueue.main)
                .assign(to: &$routeCoordinates)

            locationManager.routePointsPublisher
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

    func startWorkout() async {
        guard timerState == .idle else {
            return
        }

        resetSessionState()
        sessionID = UUID()

        _ = try? await healthKitManager.requestAuthorization()

        if workout.requiresLocationTracking {
            locationManager?.requestLocationPermission()
        }

        sessionStartDate = Date()
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
        let startDate = sessionStartDate ?? endDate
        let activeDuration = elapsedTime
        let finalSessionID = sessionID

        let finalRoutePoints = routePoints
        let finalStrengthSets = strengthSets

        let liveActiveCalories = activeCalories
        let liveStepCount = stepCount
        let liveDistance = distanceMeters

        await stopWorkout()

        let healthData = await collectFinalHealthData(
            from: startDate,
            to: endDate,
            liveActiveCalories: liveActiveCalories,
            liveStepCount: liveStepCount,
            liveDistance: liveDistance
        )

        let session = makeSession(
            id: finalSessionID,
            startDate: startDate,
            endDate: endDate,
            activeDuration: activeDuration,
            healthData: healthData,
            routePoints: finalRoutePoints,
            strengthSets: finalStrengthSets
        )

        do {
            try await sessionRepository?.saveCompleted(
                session
            )
            storageError = nil
        } catch {
            storageError = error.localizedDescription
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

        await healthKitManager.stopObservingData()
    }

    func recordLap() {
        timerManager.recordLap()

        Task {
            await saveCheckpoint()
        }
    }

    // MARK: - Strength Recording

    @discardableResult
    func recordStrengthSet(
        weightKilograms: Double,
        repetitions: Int,
        isWarmup: Bool = false
    ) -> Bool {
        guard workout.category == .strength,
              timerManager.isRunning,
              !isResting,
              weightKilograms >= 0,
              repetitions > 0 else {
            return false
        }

        let now = Date()

        strengthSets.append(
            StrengthSetRecord(
                setNumber: strengthSets.count + 1,
                weightKilograms: weightKilograms,
                repetitions: repetitions,
                endDate: now,
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
    func finishRestAndStartNextSet() -> Bool {
        guard workout.category == .strength,
              isResting,
              !strengthSets.isEmpty else {
            return false
        }

        let completedRestDuration =
            restTimerManager.elapsedTime

        restTimerManager.stop()

        strengthSets[
            strengthSets.index(before: strengthSets.endIndex)
        ].restDuration = completedRestDuration

        isResting = false

        Task {
            await saveCheckpoint()
        }

        return true
    }

    var nextStrengthSetNumber: Int {
        strengthSets.count + 1
    }

    var lastStrengthSet: StrengthSetRecord? {
        strengthSets.last
    }

    private func resetSessionState() {
        healthDataCollectionError = nil
        storageError = nil

        restTimerManager.stop()
        isResting = false
        strengthSets.removeAll()
    }

    // MARK: - Checkpoint Persistence

    private func startCheckpointLoop() {
        checkpointTask?.cancel()

        checkpointTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds:
                            Self.checkpointIntervalNanoseconds
                    )
                } catch {
                    break
                }

                guard !Task.isCancelled else {
                    break
                }

                await self?.saveCheckpoint()
            }
        }
    }

    private func saveCheckpoint() async {
        guard let sessionRepository,
              let startDate = sessionStartDate else {
            return
        }

        let liveHealthData = WorkoutHealthData(
            summary: WorkoutHealthSummary(
                averageHeartRate: nonZero(heartRate),
                activeCalories: nonZero(activeCalories),
                stepCount: nonZero(stepCount),
                distanceMeters: nonZero(distanceMeters)
            )
        )

        let checkpoint = makeSession(
            id: sessionID,
            startDate: startDate,
            endDate: nil,
            activeDuration: elapsedTime,
            healthData: liveHealthData,
            routePoints: routePoints,
            strengthSets: strengthSets
        )

        do {
            try await sessionRepository.saveCheckpoint(
                checkpoint
            )
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }

    // MARK: - Health Observation

    private func startHealthObservation() {
        healthTask?.cancel()

        healthTask = Task { [weak self] in
            guard let self else {
                return
            }

            let stream = healthKitManager.startObservingData()

            for await snapshot in stream {
                guard !Task.isCancelled else {
                    break
                }

                self.heartRate = snapshot.heartRate
                self.activeCalories = snapshot.activeCalories
                self.stepCount = snapshot.stepCount
                self.distanceMeters = snapshot.distance
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
            var healthData = try await healthKitManager
                .fetchWorkoutHealthData(
                    from: startDate,
                    to: endDate
                )

            mergeLiveTotals(
                into: &healthData,
                activeCalories: liveActiveCalories,
                stepCount: liveStepCount,
                distance: liveDistance
            )

            return healthData
        } catch {
            healthDataCollectionError = error.localizedDescription

            return WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    activeCalories: nonZero(liveActiveCalories),
                    stepCount: nonZero(liveStepCount),
                    distanceMeters: nonZero(liveDistance)
                )
            )
        }
    }

    private func mergeLiveTotals(
        into healthData: inout WorkoutHealthData,
        activeCalories: Double,
        stepCount: Double,
        distance: Double
    ) {
        if healthData.summary.activeCalories == nil {
            healthData.summary.activeCalories = nonZero(activeCalories)
        }

        if healthData.summary.stepCount == nil {
            healthData.summary.stepCount = nonZero(stepCount)
        }

        if healthData.summary.distanceMeters == nil {
            healthData.summary.distanceMeters = nonZero(distance)
        }
    }

    private func nonZero(
        _ value: Double
    ) -> Double? {
        value > 0 ? value : nil
    }

    // MARK: - Session

    private func makeSession(
        id: UUID,
        startDate: Date,
        endDate: Date?,
        activeDuration: TimeInterval,
        healthData: WorkoutHealthData,
        routePoints: [WorkoutRoutePoint],
        strengthSets: [StrengthSetRecord]
    ) -> WorkoutSession {
        let referenceDate = endDate ?? Date()

        let elapsedDuration = max(
            0,
            referenceDate.timeIntervalSince(startDate)
        )

        let normalizedActiveDuration = min(
            max(0, activeDuration),
            elapsedDuration
        )

        let timing = WorkoutTiming(
            startDate: startDate,
            endDate: endDate,
            elapsedDuration: elapsedDuration,
            activeDuration: normalizedActiveDuration,
            pausedDuration: max(
                0,
                elapsedDuration - normalizedActiveDuration
            )
        )

        let identity = WorkoutIdentity(
            workoutID: workout.id,
            name: workout.name,
            category: workout.category.rawValue,
            type: workout.type
        )

        let exerciseRecord = WorkoutExerciseRecord(
            exerciseID: workout.id,
            name: workout.name,
            kind: workout.category == .strength
                ? .strength
                : .cardio,
            startDate: startDate,
            endDate: endDate,
            strengthSets: workout.category == .strength
                ? strengthSets
                : []
        )

        return WorkoutSession(
            id: id,
            workout: identity,
            timing: timing,
            exerciseRecords: [exerciseRecord],
            health: healthData,
            route: routePoints
        )
    }

    // MARK: - UI Values

    var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
}
