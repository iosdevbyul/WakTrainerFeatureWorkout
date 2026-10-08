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
    func loadWorkoutsLoadsRepositoryWorkouts()
        async {
        let repository =
            SelectionMockWorkoutCatalogRepository(
                workouts: [
                    WorkoutDefinition(
                        id: "running",
                        name: "Running",
                        category: .cardio,
                        type: .dynamicWorkout
                    ),
                    WorkoutDefinition(
                        id: "squat",
                        name: "Squat",
                        category: .strength,
                        type: .staticWorkout
                    )
                ]
            )

        let viewModel =
            WorkoutSelectionViewModel(
                fetchWorkoutsUseCase:
                    FetchWorkoutsUseCase(
                        repository:
                            repository
                    ),
                preferenceStore:
                    SelectionTestPreferenceStore()
            )

        await viewModel.loadWorkouts()

        #expect(
            viewModel.workouts.count
                == 2
        )
        #expect(
            viewModel.errorMessage
                == nil
        )
        #expect(!viewModel.isLoading)
    }

    @Test
    func filteredWorkoutsReturnsSelectedCategoryOnly()
        async {
        let repository =
            SelectionMockWorkoutCatalogRepository(
                workouts: [
                    WorkoutDefinition(
                        id: "running",
                        name: "Running",
                        category: .cardio,
                        type: .dynamicWorkout
                    ),
                    WorkoutDefinition(
                        id: "walking",
                        name: "Walking",
                        category: .cardio,
                        type: .dynamicWorkout
                    ),
                    WorkoutDefinition(
                        id: "squat",
                        name: "Squat",
                        category: .strength,
                        type: .staticWorkout
                    )
                ]
            )

        let viewModel =
            WorkoutSelectionViewModel(
                fetchWorkoutsUseCase:
                    FetchWorkoutsUseCase(
                        repository:
                            repository
                    ),
                preferenceStore:
                    SelectionTestPreferenceStore()
            )

        await viewModel.loadWorkouts()
        viewModel.selectedCategory =
            .cardio

        #expect(
            viewModel
                .filteredWorkouts
                .count
                == 2
        )
    }

    @Test
    func togglingFavoritePersistsSelection()
        async {
        let workout =
            WorkoutDefinition(
                id: "running",
                name: "Running",
                category: .cardio,
                type: .dynamicWorkout
            )
        let preferences =
            SelectionTestPreferenceStore()
        let repository =
            SelectionMockWorkoutCatalogRepository(
                workouts: [
                    workout
                ]
            )
        let viewModel =
            WorkoutSelectionViewModel(
                fetchWorkoutsUseCase:
                    FetchWorkoutsUseCase(
                        repository:
                            repository
                    ),
                preferenceStore:
                    preferences
            )

        await viewModel.loadWorkouts()

        #expect(
            !viewModel
                .isFavorite(
                    workout
                )
        )

        viewModel.toggleFavorite(
            workout
        )

        #expect(
            viewModel
                .isFavorite(
                    workout
                )
        )
        #expect(
            preferences
                .favoriteWorkoutIDs
                .contains(
                    workout.id
                )
        )

        viewModel.toggleFavorite(
            workout
        )

        #expect(
            !viewModel
                .isFavorite(
                    workout
                )
        )
    }
}

private struct SelectionMockWorkoutCatalogRepository:
    WorkoutCatalogRepository {

    let workouts:
        [WorkoutDefinition]

    func fetchWorkouts() async throws
        -> [WorkoutDefinition] {
        workouts
    }
}

private final class SelectionTestPreferenceStore:
    WorkoutLauncherPreferenceStore,
    @unchecked Sendable {

    private(set) var favoriteWorkoutIDs:
        Set<String> = []

    func setFavorite(
        _ isFavorite: Bool,
        workoutID: String
    ) {
        if isFavorite {
            favoriteWorkoutIDs
                .insert(workoutID)
        } else {
            favoriteWorkoutIDs
                .remove(workoutID)
        }
    }
}
