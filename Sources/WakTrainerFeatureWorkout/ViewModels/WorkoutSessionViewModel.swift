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
    private(set) var timerManager: TimerManager

    // MARK: - Health Data

    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var stepCount: Double = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var healthDataCollectionError: String?

    // MARK: - Location Data

    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var routePoints: [WorkoutRoutePoint] = []

    // MARK: - Timer Data

    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var laps: [LapItem] = []

    // MARK: - Session State

    private var sessionStartDate: Date?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var healthTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        workout: WorkoutDefinition,
        healthKitManager: HealthKitManagerProtocol = HealthKitManager(),
        locationManager: (any WorkoutLocationManaging)? = nil,
        timerManager: TimerManager = TimerManager()
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

        self.timerManager = timerManager

        setupSubscriptions()
    }

    deinit {
        healthTask?.cancel()
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
    }

    // MARK: - Workout Actions

    func startWorkout() async {
        guard timerState == .idle else {
            return
        }

        healthDataCollectionError = nil

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
    }

    func pauseWorkout() {
        timerManager.pause()
    }

    func resumeWorkout() {
        timerManager.start()
    }

    func finishWorkout() async -> WorkoutSession {
        let endDate = Date()
        let startDate = sessionStartDate ?? endDate
        let activeDuration = elapsedTime

        let finalRoutePoints = routePoints

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

        sessionStartDate = nil

        return makeSession(
            startDate: startDate,
            endDate: endDate,
            activeDuration: activeDuration,
            healthData: healthData,
            routePoints: finalRoutePoints
        )
    }

    private func stopWorkout() async {
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
        startDate: Date,
        endDate: Date,
        activeDuration: TimeInterval,
        healthData: WorkoutHealthData,
        routePoints: [WorkoutRoutePoint]
    ) -> WorkoutSession {
        let elapsedDuration = max(
            0,
            endDate.timeIntervalSince(startDate)
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
            endDate: endDate
        )

        return WorkoutSession(
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
