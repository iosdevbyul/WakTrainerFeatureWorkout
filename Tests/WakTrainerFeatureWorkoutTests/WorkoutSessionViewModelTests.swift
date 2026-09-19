//
//  WorkoutSessionViewModelTests.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer

@testable import WakTrainerFeatureWorkout

@MainActor
struct WorkoutSessionViewModelTests {

    @Test
    func finishWorkoutReturnsResultAndStopsResources() async throws {
        let healthKitManager = MockHealthKitManager(
            snapshot: HealthSnapshot(
                heartRate: 120,
                stepCount: 300,
                activeCalories: 42,
                distance: 700
            )
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
            nanoseconds: 200_000_000
        )

        let result = await viewModel.finishWorkout()

        #expect(result.workoutID == "squat")
        #expect(result.workoutName == "스쿼트")

        #expect(result.duration > 0)

        #expect(result.activeCalories == 42)
        #expect(result.stepCount == 300)
        #expect(result.distanceMeters == 700)

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
    }
}

private final class MockHealthKitManager:
    HealthKitManagerProtocol,
    @unchecked Sendable
{
    private let lock = NSLock()

    private let snapshot: HealthSnapshot

    private var _requestAuthorizationCallCount = 0
    private var _startObservingCallCount = 0
    private var _stopObservingCallCount = 0

    init(
        snapshot: HealthSnapshot
    ) {
        self.snapshot = snapshot
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

    func startObservingData() -> AsyncStream<HealthSnapshot> {
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
}
