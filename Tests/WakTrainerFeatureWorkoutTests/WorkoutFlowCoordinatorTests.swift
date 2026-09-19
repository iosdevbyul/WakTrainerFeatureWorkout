//
//  WorkoutFlowCoordinatorTests.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

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
    func finishWorkoutMovesToCompletion() {
        let coordinator = WorkoutFlowCoordinator()

        let result = WorkoutFeatureResult(
            workoutID: "running",
            workoutName: "달리기",
            duration: 600,
            distanceMeters: 2_000,
            activeCalories: 150,
            stepCount: 2_500
        )

        coordinator.finishWorkout(result)

        guard case .completion(let completedResult) = coordinator.state else {
            Issue.record("Expected state to be completion")
            return
        }

        #expect(completedResult.workoutID == "running")
        #expect(completedResult.workoutName == "달리기")
        #expect(completedResult.duration == 600)
        #expect(completedResult.distanceMeters == 2_000)
        #expect(completedResult.activeCalories == 150)
        #expect(completedResult.stepCount == 2_500)
    }
}
