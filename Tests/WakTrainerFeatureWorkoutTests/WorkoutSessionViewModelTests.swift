//
//  WorkoutSessionViewModelTests.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Combine
import CoreLocation
import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer

@testable import WakTrainerFeatureWorkout

@MainActor
struct WorkoutSessionViewModelTests {

    @Test
    func cardioWorkoutBuildsSessionAndStopsResources() async throws {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let heartRateSample = WorkoutHealthMetricSample(
            metric: .heartRate,
            startDate: start,
            endDate: start.addingTimeInterval(5),
            value: 132,
            unit: "bpm"
        )

        let finalHealthData = WorkoutHealthData(
            summary: WorkoutHealthSummary(
                averageHeartRate: 132,
                activeCalories: 210,
                stepCount: 1_500,
                distanceMeters: 2_400
            ),
            samples: [heartRateSample]
        )

        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(
                heartRate: 120,
                stepCount: 300,
                activeCalories: 42,
                distance: 700
            ),
            finalHealthData: finalHealthData
        )

        let timerManager = TimerManager()
        let locationManager =
            MockWorkoutLocationManager()

        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "running",
                name: "Running",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: healthKitManager,
            locationManager: locationManager,
            timerManager: timerManager
        )

        await viewModel.startWorkout()

        let didAdvanceTimer =
            await waitUntil {
                viewModel.elapsedTime > 0
            }

        #expect(didAdvanceTimer)

        let session = await viewModel.finishWorkout()

        #expect(session.workout.workoutID == "running")
        #expect(session.workout.name == "Running")
        #expect(session.workout.category == "cardio")
        #expect(session.workout.type == .dynamicWorkout)

        #expect(session.timing.endDate != nil)
        #expect(session.timing.activeDuration > 0)
        #expect(
            session.timing.elapsedDuration
                >= session.timing.activeDuration
        )

        #expect(
            session.health.summary.activeCalories == 210
        )
        #expect(
            session.health.summary.stepCount == 1_500
        )
        #expect(
            session.health.summary.distanceMeters == 2_400
        )
        #expect(session.health.samples.count == 1)

        #expect(session.exerciseRecords.count == 1)
        #expect(
            session.exerciseRecords.first?.exerciseID
                == "running"
        )
        #expect(
            session.exerciseRecords.first?.kind
                == .cardio
        )

        #expect(timerManager.state == .idle)
        #expect(timerManager.elapsedTime == 0)

        #expect(
            healthKitManager.requestAuthorizationCallCount == 1
        )
        #expect(
            healthKitManager.startObservingCallCount == 1
        )
        #expect(
            healthKitManager.stopObservingCallCount == 1
        )
        #expect(
            healthKitManager.fetchWorkoutHealthDataCallCount == 1
        )
    }

    @Test
    func dynamicWorkoutPreservesRoutePointsInSession() async {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(),
            finalHealthData: WorkoutHealthData()
        )

        let locationManager =
            MockWorkoutLocationManager()

        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "cycling",
                name: "Cycling",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: healthKitManager,
            locationManager: locationManager,
            timerManager: TimerManager()
        )

        await viewModel.startWorkout()

        let first = WorkoutRoutePoint(
            timestamp: Date(
                timeIntervalSince1970: 1_000
            ),
            latitude: 37.1,
            longitude: 127.1,
            altitude: 20,
            speedMetersPerSecond: 2.5,
            horizontalAccuracy: 4,
            verticalAccuracy: 6,
            course: 90
        )

        let second = WorkoutRoutePoint(
            timestamp: Date(
                timeIntervalSince1970: 1_005
            ),
            latitude: 37.2,
            longitude: 127.2,
            altitude: 24,
            speedMetersPerSecond: 3,
            horizontalAccuracy: 4,
            verticalAccuracy: 6,
            course: 95
        )

        locationManager.send(
            routePoints: [first, second]
        )

        let didReceiveRoute = await waitUntil {
            viewModel.routePoints.count == 2
        }

        #expect(didReceiveRoute)

        let session = await viewModel.finishWorkout()

        #expect(
            locationManager.requestLocationPermissionCallCount == 1
        )
        #expect(
            locationManager.startTrackingCallCount == 1
        )
        #expect(
            locationManager.stopTrackingCallCount == 1
        )
        #expect(session.route == [first, second])
    }

    @Test
    func strengthWorkoutRequiresExerciseAndEquipmentBeforeStart() async {
        let viewModel = makeStrengthViewModel()

        await viewModel.startWorkout()

        #expect(viewModel.timerState == .idle)
        #expect(!viewModel.canStartWorkout)

        let didSelect =
            viewModel.beginStrengthExercise(
                squatDefinition,
                equipment: .barbell
            )

        #expect(didSelect)
        #expect(viewModel.canStartWorkout)

        await viewModel.startWorkout()

        let didStart =
            await waitUntil {
                viewModel.timerState
                    == .running
            }

        #expect(didStart)

        _ = await viewModel.finishWorkout()
    }

    @Test
    func strengthWorkoutStoresMultipleExercisesInOneSession() async throws {
        let viewModel = makeStrengthViewModel()

        #expect(
            viewModel.beginStrengthExercise(
                squatDefinition,
                equipment: .barbell
            )
        )

        await viewModel.startWorkout()

        #expect(
            viewModel.recordStrengthSet(
                weightKilograms: 80,
                repetitions: 8
            )
        )

        #expect(
            viewModel.finishRestAndStartNextSet()
        )

        #expect(
            viewModel.recordStrengthSet(
                weightKilograms: 90,
                repetitions: 6
            )
        )

        #expect(
            viewModel.beginStrengthExercise(
                benchPressDefinition,
                equipment: .dumbbell
            )
        )

        #expect(
            viewModel.completedStrengthExerciseRecords.count
                == 1
        )

        #expect(
            viewModel.recordStrengthSet(
                weightKilograms: 30,
                repetitions: 10
            )
        )

        let session = await viewModel.finishWorkout()

        #expect(
            session.workout.workoutID
                == "strength_training"
        )
        #expect(
            session.workout.name
                == "Strength Training"
        )
        #expect(session.exerciseRecords.count == 2)

        let squat =
            try #require(
                session.exerciseRecords
                    .first
            )
        let bench =
            try #require(
                session.exerciseRecords
                    .last
            )

        #expect(squat.exerciseID == "squat")
        #expect(squat.strengthEquipment == .barbell)
        #expect(squat.strengthSets.count == 2)

        #expect(bench.exerciseID == "bench_press")
        #expect(bench.strengthEquipment == .dumbbell)
        #expect(bench.strengthSets.count == 1)
    }

    @Test
    func bodyweightStrengthSetStoresRepsWithoutWeight() async throws {
        let viewModel = makeStrengthViewModel()

        #expect(
            viewModel.beginStrengthExercise(
                squatDefinition,
                equipment: .bodyweight
            )
        )

        await viewModel.startWorkout()

        #expect(
            viewModel.recordStrengthSet(
                weightKilograms: nil,
                repetitions: 20
            )
        )

        let session = await viewModel.finishWorkout()

        let set =
            try #require(
                session.exerciseRecords
                    .first?
                    .strengthSets
                    .first
            )

        #expect(set.weightKilograms == nil)
        #expect(set.repetitions == 20)
    }

    @Test
    func strengthWorkoutDoesNotStartLocationTracking() async {
        let locationManager =
            MockWorkoutLocationManager()

        let viewModel = WorkoutSessionViewModel(
            workout: strengthWorkout,
            healthKitManager: MockHealthKitManager(
                snapshot: HealthSnapshot(),
                finalHealthData: WorkoutHealthData()
            ),
            locationManager: locationManager,
            strengthLocationPolicy: .registeredPlace,
            timerManager: TimerManager()
        )

        #expect(
            viewModel.beginStrengthExercise(
                squatDefinition,
                equipment: .barbell
            )
        )

        await viewModel.startWorkout()

        #expect(
            locationManager.requestLocationPermissionCallCount
                == 0
        )
        #expect(
            locationManager.startTrackingCallCount
                == 0
        )

        _ = await viewModel.finishWorkout()

        #expect(
            locationManager.stopTrackingCallCount
                == 0
        )
    }

    @Test
    func unregisteredStrengthWorkoutCapturesLocationOnce() async {
        let locationManager = MockWorkoutLocationManager()
        let viewModel = WorkoutSessionViewModel(
            workout: strengthWorkout,
            healthKitManager: MockHealthKitManager(
                snapshot: HealthSnapshot(),
                finalHealthData: WorkoutHealthData()
            ),
            locationManager: locationManager,
            strengthLocationPolicy: .singleLocation,
            timerManager: TimerManager()
        )
        #expect(viewModel.beginStrengthExercise(squatDefinition, equipment: .barbell))
        await viewModel.startWorkout()
        #expect(locationManager.requestLocationPermissionCallCount == 1)
        #expect(locationManager.startTrackingCallCount == 1)
        _ = await viewModel.finishWorkout()
        #expect(locationManager.stopTrackingCallCount == 1)
    }

    @Test
    func disabledStrengthLocationSkipsGPS() async {
        let locationManager = MockWorkoutLocationManager()
        let viewModel = WorkoutSessionViewModel(
            workout: strengthWorkout,
            healthKitManager: MockHealthKitManager(
                snapshot: HealthSnapshot(),
                finalHealthData: WorkoutHealthData()
            ),
            locationManager: locationManager,
            strengthLocationPolicy: .disabled,
            timerManager: TimerManager()
        )
        #expect(viewModel.beginStrengthExercise(squatDefinition, equipment: .barbell))
        await viewModel.startWorkout()
        _ = await viewModel.finishWorkout()
        #expect(locationManager.requestLocationPermissionCallCount == 0)
        #expect(locationManager.startTrackingCallCount == 0)
        #expect(locationManager.stopTrackingCallCount == 1)
    }

    @Test
    func pauseTimeIsSeparatedFromActiveTime() async throws {
        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "running",
                name: "Running",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: MockHealthKitManager(
                snapshot: HealthSnapshot(),
                finalHealthData: WorkoutHealthData()
            ),
            locationManager:
                MockWorkoutLocationManager(),
            timerManager: TimerManager()
        )

        await viewModel.startWorkout()

        try await Task.sleep(
            nanoseconds: 100_000_000
        )

        viewModel.pauseWorkout()

        try await Task.sleep(
            nanoseconds: 150_000_000
        )

        viewModel.resumeWorkout()

        try await Task.sleep(
            nanoseconds: 100_000_000
        )

        let session = await viewModel.finishWorkout()

        #expect(session.timing.activeDuration > 0)
        #expect(session.timing.pausedDuration > 0)
        #expect(
            session.timing.elapsedDuration
                > session.timing.activeDuration
        )
    }

    @Test
    func healthQueryFailureDoesNotLoseWorkoutSession() async throws {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(
                heartRate: 120,
                stepCount: 300,
                activeCalories: 42,
                distance: 700
            ),
            finalHealthData: WorkoutHealthData(),
            fetchError: TestHealthError.fetchFailed
        )

        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "walking",
                name: "Walking",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: healthKitManager,
            locationManager:
                MockWorkoutLocationManager(),
            timerManager: TimerManager()
        )

        await viewModel.startWorkout()

        let didReceiveLiveHealth =
            await waitUntil {
                viewModel.activeCalories
                    == 42
                && viewModel.stepCount
                    == 300
                && viewModel.distanceMeters
                    == 700
            }

        #expect(didReceiveLiveHealth)

        let session = await viewModel.finishWorkout()

        #expect(
            session.workout.workoutID
                == "walking"
        )
        #expect(
            session.health.summary.activeCalories
                == 42
        )
        #expect(
            session.health.summary.stepCount
                == 300
        )
        #expect(
            session.health.summary.distanceMeters
                == 700
        )
        #expect(
            viewModel.healthDataCollectionError
                != nil
        )
    }

    @Test
    func weightedExerciseRejectsMissingWeight() async {
        let viewModel = makeStrengthViewModel()

        #expect(
            viewModel.beginStrengthExercise(
                benchPressDefinition,
                equipment: .barbell
            )
        )

        await viewModel.startWorkout()

        let recorded =
            viewModel.recordStrengthSet(
                weightKilograms: nil,
                repetitions: 8
            )

        #expect(!recorded)
        #expect(viewModel.strengthSets.isEmpty)

        _ = await viewModel.finishWorkout()
    }

    @Test
    func cardioWorkoutRejectsStrengthSetRecording() async {
        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "running",
                name: "Running",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: MockHealthKitManager(
                snapshot: HealthSnapshot(),
                finalHealthData: WorkoutHealthData()
            ),
            locationManager:
                MockWorkoutLocationManager(),
            timerManager: TimerManager(),
            restTimerManager: TimerManager()
        )

        await viewModel.startWorkout()

        let recorded =
            viewModel.recordStrengthSet(
                weightKilograms: 80,
                repetitions: 8
            )

        #expect(!recorded)
        #expect(viewModel.strengthSets.isEmpty)
        #expect(!viewModel.isResting)

        _ = await viewModel.finishWorkout()
    }

    private var strengthWorkout:
        WorkoutDefinition {
        WorkoutDefinition(
            id: "strength_training",
            name: "Strength Training",
            category: .strength,
            type: .staticWorkout
        )
    }

    private var squatDefinition:
        StrengthExerciseDefinition {
        StrengthExerciseDefinition(
            id: "squat",
            name: "Squat",
            supportedEquipment: [
                .barbell,
                .dumbbell,
                .bodyweight
            ]
        )
    }

    private var benchPressDefinition:
        StrengthExerciseDefinition {
        StrengthExerciseDefinition(
            id: "bench_press",
            name: "Bench Press",
            supportedEquipment: [
                .barbell,
                .dumbbell,
                .machine
            ]
        )
    }

    private func makeStrengthViewModel()
        -> WorkoutSessionViewModel {
        WorkoutSessionViewModel(
            workout: strengthWorkout,
            healthKitManager:
                MockHealthKitManager(
                    snapshot:
                        HealthSnapshot(),
                    finalHealthData:
                        WorkoutHealthData()
                ),
            timerManager:
                TimerManager(),
            restTimerManager:
                TimerManager()
        )
    }
}

@MainActor
private final class MockWorkoutLocationManager:
    WorkoutLocationManaging {

    private let userLocationSubject =
        CurrentValueSubject<CLLocation?, Never>(nil)

    private let routeCoordinatesSubject =
        CurrentValueSubject<
            [CLLocationCoordinate2D],
            Never
        >([])

    private let routePointsSubject =
        CurrentValueSubject<
            [WorkoutRoutePoint],
            Never
        >([])

    private(set)
    var requestLocationPermissionCallCount = 0

    private(set)
    var startTrackingCallCount = 0

    private(set)
    var stopTrackingCallCount = 0

    var userLocationPublisher: AnyPublisher<
        CLLocation?,
        Never
    > {
        userLocationSubject.eraseToAnyPublisher()
    }

    var routeCoordinatesPublisher: AnyPublisher<
        [CLLocationCoordinate2D],
        Never
    > {
        routeCoordinatesSubject.eraseToAnyPublisher()
    }

    var routePointsPublisher: AnyPublisher<
        [WorkoutRoutePoint],
        Never
    > {
        routePointsSubject.eraseToAnyPublisher()
    }

    func requestLocationPermission() {
        requestLocationPermissionCallCount += 1
    }

    func startTracking() {
        startTrackingCallCount += 1
    }

    func stopTracking() {
        stopTrackingCallCount += 1
    }

    func send(
        routePoints: [WorkoutRoutePoint]
    ) {
        routePointsSubject.send(routePoints)
        routeCoordinatesSubject.send(
            routePoints.map(\.coordinate)
        )
    }
}

private enum TestHealthError: Error {
    case fetchFailed
}

private final class MockHealthKitManager:
    HealthKitManagerProtocol,
    @unchecked Sendable {

    private let lock = NSLock()

    private let snapshot: HealthSnapshot
    private let finalHealthData: WorkoutHealthData
    private let fetchError: Error?

    private var _requestAuthorizationCallCount = 0
    private var _startObservingCallCount = 0
    private var _stopObservingCallCount = 0
    private var _fetchWorkoutHealthDataCallCount = 0

    private var _fetchedStartDate: Date?
    private var _fetchedEndDate: Date?

    init(
        snapshot: HealthSnapshot,
        finalHealthData: WorkoutHealthData,
        fetchError: Error? = nil
    ) {
        self.snapshot = snapshot
        self.finalHealthData = finalHealthData
        self.fetchError = fetchError
    }

    var isAuthorized: Bool {
        get async {
            true
        }
    }

    func requestAuthorization() async throws -> Bool {
        lock.withLock {
            _requestAuthorizationCallCount += 1
        }

        return true
    }

    func startObservingData()
        -> AsyncStream<HealthSnapshot> {

        lock.withLock {
            _startObservingCallCount += 1
        }

        let snapshot = snapshot

        return AsyncStream { continuation in
            continuation.yield(snapshot)
            continuation.finish()
        }
    }

    func stopObservingData() async {
        lock.withLock {
            _stopObservingCallCount += 1
        }
    }

    func fetchWorkoutHealthData(
        from startDate: Date,
        to endDate: Date
    ) async throws -> WorkoutHealthData {
        lock.withLock {
            _fetchWorkoutHealthDataCallCount += 1
            _fetchedStartDate = startDate
            _fetchedEndDate = endDate
        }

        if let fetchError {
            throw fetchError
        }

        return finalHealthData
    }

    var requestAuthorizationCallCount: Int {
        lock.withLock {
            _requestAuthorizationCallCount
        }
    }

    var startObservingCallCount: Int {
        lock.withLock {
            _startObservingCallCount
        }
    }

    var stopObservingCallCount: Int {
        lock.withLock {
            _stopObservingCallCount
        }
    }

    var fetchWorkoutHealthDataCallCount: Int {
        lock.withLock {
            _fetchWorkoutHealthDataCallCount
        }
    }

    var fetchedDateRange: (
        start: Date,
        end: Date
    )? {
        lock.withLock {
            guard let start =
                    _fetchedStartDate,
                  let end =
                    _fetchedEndDate else {
                return nil
            }

            return (
                start,
                end
            )
        }
    }
}

@MainActor
private func waitUntil(
    _ condition: () -> Bool
) async -> Bool {
    for _ in 0..<250 {
        if condition() {
            return true
        }

        try? await Task.sleep(
            nanoseconds: 10_000_000
        )
    }

    return condition()
}
