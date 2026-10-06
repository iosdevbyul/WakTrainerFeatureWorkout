//
//  WorkoutFlowCoordinatorTests.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
struct WorkoutFlowCoordinatorTests {

    @Test
    func initialStateIsSelection() {
        let coordinator = WorkoutFlowCoordinator()

        guard case .selection = coordinator.state else {
            Issue.record("Expected initial state to be selection")
            return
        }
    }


    @Test
    func initialWorkoutStartsInSessionState() {
        let workout = WorkoutDefinition(
            id: "running",
            name: "달리기",
            category: .cardio,
            type: .dynamicWorkout
        )

        let coordinator = WorkoutFlowCoordinator(
            initialWorkout: workout
        )

        guard case .session(let selectedWorkout) =
                coordinator.state else {
            Issue.record(
                "Expected initial state to be session"
            )
            return
        }

        #expect(selectedWorkout == workout)
    }

    @Test
    func selectWorkoutMovesToSession() {
        let coordinator = WorkoutFlowCoordinator()

        let workout = WorkoutDefinition(
            id: "running",
            name: "달리기",
            category: .cardio,
            type: .dynamicWorkout
        )

        coordinator.selectWorkout(workout)

        guard case .session(let selectedWorkout) = coordinator.state else {
            Issue.record("Expected state to be session")
            return
        }

        #expect(selectedWorkout == workout)
    }

    @Test
    func returnToSelectionMovesBackFromSession() {
        let coordinator = WorkoutFlowCoordinator()

        let workout = WorkoutDefinition(
            id: "squat",
            name: "스쿼트",
            category: .strength,
            type: .staticWorkout
        )

        coordinator.selectWorkout(workout)
        coordinator.returnToSelection()

        guard case .selection = coordinator.state else {
            Issue.record("Expected state to return to selection")
            return
        }
    }

    @Test
    func finishWorkoutMovesToCompletionWithSession() {
        let coordinator = WorkoutFlowCoordinator()

        let startDate = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: startDate,
                endDate: startDate.addingTimeInterval(600),
                elapsedDuration: 600,
                activeDuration: 570,
                pausedDuration: 30
            ),
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    activeCalories: 150,
                    stepCount: 2_500,
                    distanceMeters: 2_000
                )
            )
        )

        coordinator.finishWorkout(session)

        guard case .completion(let completedSession) = coordinator.state else {
            Issue.record("Expected state to be completion")
            return
        }

        #expect(completedSession == session)
        #expect(completedSession.workout.workoutID == "running")
        #expect(completedSession.timing.activeDuration == 570)
        #expect(completedSession.health.summary.distanceMeters == 2_000)
    }
}
