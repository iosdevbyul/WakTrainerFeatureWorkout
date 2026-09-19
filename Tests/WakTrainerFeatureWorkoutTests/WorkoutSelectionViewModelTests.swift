//
//  WorkoutSelectionViewModelTests.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
struct WorkoutSelectionViewModelTests {

    @Test
    func loadWorkoutsLoadsRepositoryWorkouts() async {
        let repository = MockWorkoutCatalogRepository(
            workouts: [
                WorkoutDefinition(
                    id: "running",
                    name: "달리기",
                    category: .cardio,
                    type: .dynamicWorkout
                ),
                WorkoutDefinition(
                    id: "squat",
                    name: "스쿼트",
                    category: .strength,
                    type: .staticWorkout
                )
            ]
        )

        let useCase = FetchWorkoutsUseCase(
            repository: repository
        )

        let viewModel = WorkoutSelectionViewModel(
            fetchWorkoutsUseCase: useCase
        )

        await viewModel.loadWorkouts()

        #expect(viewModel.workouts.count == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func filteredWorkoutsReturnsSelectedCategoryOnly() async {
        let repository = MockWorkoutCatalogRepository(
            workouts: [
                WorkoutDefinition(
                    id: "running",
                    name: "달리기",
                    category: .cardio,
                    type: .dynamicWorkout
                ),
                WorkoutDefinition(
                    id: "walking",
                    name: "걷기",
                    category: .cardio,
                    type: .dynamicWorkout
                ),
                WorkoutDefinition(
                    id: "squat",
                    name: "스쿼트",
                    category: .strength,
                    type: .staticWorkout
                )
            ]
        )

        let useCase = FetchWorkoutsUseCase(
            repository: repository
        )

        let viewModel = WorkoutSelectionViewModel(
            fetchWorkoutsUseCase: useCase
        )

        await viewModel.loadWorkouts()

        viewModel.selectedCategory = .cardio

        #expect(viewModel.filteredWorkouts.count == 2)
        #expect(
            viewModel.filteredWorkouts.allSatisfy {
                $0.category == .cardio
            }
        )
    }
}

private struct MockWorkoutCatalogRepository: WorkoutCatalogRepository {

    let workouts: [WorkoutDefinition]

    func fetchWorkouts() async throws -> [WorkoutDefinition] {
        workouts
    }
}
