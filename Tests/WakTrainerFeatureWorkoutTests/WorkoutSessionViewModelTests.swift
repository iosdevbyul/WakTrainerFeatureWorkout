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
    func finishWorkoutBuildsSessionAndStopsResources() async throws {
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

        let workout = WorkoutDefinition(
            id: "squat",
            name: "스쿼트",
            category: .strength,
            type: .staticWorkout
        )

        let viewModel = WorkoutSessionViewModel(
            workout: workout,
            healthKitManager: healthKitManager,
            timerManager: timerManager
        )

        await viewModel.startWorkout()

        try await Task.sleep(
            nanoseconds: 150_000_000
        )

        let session = await viewModel.finishWorkout()

        #expect(session.workout.workoutID == "squat")
        #expect(session.workout.name == "스쿼트")
        #expect(session.workout.category == "strength")
        #expect(session.workout.type == .staticWorkout)

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
                == "squat"
        )
        #expect(
            session.exerciseRecords.first?.kind
                == .strength
        )

        #expect(session.route.isEmpty)

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

        let fetchedRange =
            healthKitManager.fetchedDateRange

        #expect(fetchedRange?.start != nil)
        #expect(fetchedRange?.end != nil)

        if let fetchedRange {
            #expect(fetchedRange.end > fetchedRange.start)
        }
    }

    @Test
    func dynamicWorkoutPreservesRoutePointsInSession() async {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(),
            finalHealthData: WorkoutHealthData()
        )

        let locationManager =
            MockWorkoutLocationManager()

        let workout = WorkoutDefinition(
            id: "running",
            name: "달리기",
            category: .cardio,
            type: .dynamicWorkout
        )

        let viewModel = WorkoutSessionViewModel(
            workout: workout,
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
            locationManager
                .requestLocationPermissionCallCount == 1
        )
        #expect(
            locationManager.startTrackingCallCount == 1
        )
        #expect(
            locationManager.stopTrackingCallCount == 1
        )

        #expect(session.route == [first, second])
        #expect(
            session.exerciseRecords.first?.kind
                == .cardio
        )
    }

    @Test
    func staticWorkoutDoesNotStartLocationTracking() async {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(),
            finalHealthData: WorkoutHealthData()
        )

        let locationManager =
            MockWorkoutLocationManager()

        let workout = WorkoutDefinition(
            id: "squat",
            name: "스쿼트",
            category: .strength,
            type: .staticWorkout
        )

        let viewModel = WorkoutSessionViewModel(
            workout: workout,
            healthKitManager: healthKitManager,
            locationManager: locationManager,
            timerManager: TimerManager()
        )

        await viewModel.startWorkout()

        #expect(
            locationManager
                .requestLocationPermissionCallCount == 0
        )
        #expect(
            locationManager.startTrackingCallCount == 0
        )

        _ = await viewModel.finishWorkout()

        #expect(
            locationManager.stopTrackingCallCount == 0
        )
    }

    @Test
    func pauseTimeIsSeparatedFromActiveTime() async throws {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(),
            finalHealthData: WorkoutHealthData()
        )

        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "squat",
                name: "스쿼트",
                category: .strength,
                type: .staticWorkout
            ),
            healthKitManager: healthKitManager,
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
                id: "running",
                name: "달리기",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: healthKitManager,
            locationManager: MockWorkoutLocationManager(),
            timerManager: TimerManager()
        )

        await viewModel.startWorkout()

        try await Task.sleep(
            nanoseconds: 100_000_000
        )

        let session = await viewModel.finishWorkout()

        #expect(session.workout.workoutID == "running")
        #expect(
            session.health.summary.activeCalories == 42
        )
        #expect(
            session.health.summary.stepCount == 300
        )
        #expect(
            session.health.summary.distanceMeters == 700
        )
        #expect(
            viewModel.healthDataCollectionError != nil
        )
    }

    @Test
    func strengthSetRecordingPreservesSetsAndRestDuration() async throws {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(),
            finalHealthData: WorkoutHealthData()
        )

        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "bench_press",
                name: "벤치프레스",
                category: .strength,
                type: .staticWorkout
            ),
            healthKitManager: healthKitManager,
            timerManager: TimerManager(),
            restTimerManager: TimerManager()
        )

        await viewModel.startWorkout()

        let firstRecorded = viewModel.recordStrengthSet(
            weightKilograms: 80,
            repetitions: 8
        )

        #expect(firstRecorded)

        let firstSet =
            try #require(
                viewModel.strengthSets.first
            )

        #expect(viewModel.strengthSets.count == 1)
        #expect(firstSet.setNumber == 1)
        #expect(firstSet.weightKilograms == 80)
        #expect(firstSet.repetitions == 8)
        #expect(firstSet.volumeKilograms == 640)
        #expect(viewModel.isResting)

        let duplicateDuringRest =
            viewModel.recordStrengthSet(
                weightKilograms: 80,
                repetitions: 8
            )

        #expect(!duplicateDuringRest)

        try await Task.sleep(
            nanoseconds: 120_000_000
        )

        let didFinishRest =
            viewModel.finishRestAndStartNextSet()

        #expect(didFinishRest)
        #expect(!viewModel.isResting)

        let restedFirstSet =
            try #require(
                viewModel.strengthSets.first
            )

        #expect(
            (restedFirstSet.restDuration ?? 0)
                > 0
        )

        let secondRecorded =
            viewModel.recordStrengthSet(
                weightKilograms: 82.5,
                repetitions: 6
            )

        #expect(secondRecorded)
        #expect(viewModel.strengthSets.count == 2)
        #expect(viewModel.nextStrengthSetNumber == 3)

        let session = await viewModel.finishWorkout()

        let storedSets =
            try #require(
                session
                    .exerciseRecords
                    .first?
                    .strengthSets
            )

        #expect(storedSets.count == 2)

        let storedFirstSet =
            try #require(
                storedSets.first
            )

        let storedLastSet =
            try #require(
                storedSets.last
            )

        #expect(storedFirstSet.weightKilograms == 80)
        #expect(storedFirstSet.repetitions == 8)
        #expect(
            (storedFirstSet.restDuration ?? 0) > 0
        )
        #expect(storedLastSet.weightKilograms == 82.5)
        #expect(storedLastSet.repetitions == 6)
    }

    @Test
    func cardioWorkoutRejectsStrengthSetRecording() async {
        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "running",
                name: "달리기",
                category: .cardio,
                type: .dynamicWorkout
            ),
            healthKitManager: MockHealthKitManager(
                snapshot: HealthSnapshot(),
                finalHealthData: WorkoutHealthData()
            ),
            locationManager: MockWorkoutLocationManager(),
            timerManager: TimerManager(),
            restTimerManager: TimerManager()
        )

        await viewModel.startWorkout()

        let recorded = viewModel.recordStrengthSet(
            weightKilograms: 80,
            repetitions: 8
        )

        #expect(!recorded)
        #expect(viewModel.strengthSets.isEmpty)
        #expect(!viewModel.isResting)

        _ = await viewModel.finishWorkout()
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
    for _ in 0..<100 {
        if condition() {
            return true
        }

        try? await Task.sleep(
            nanoseconds: 10_000_000
        )
    }

    return condition()
}
