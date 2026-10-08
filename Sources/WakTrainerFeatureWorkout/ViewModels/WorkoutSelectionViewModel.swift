import Foundation
import WakTrainerDomainWorkout

@MainActor
final class WorkoutSelectionViewModel:
    ObservableObject {

    @Published private(set) var workouts:
        [WorkoutDefinition] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage:
        String?
    @Published private(set) var favoriteWorkoutIDs:
        Set<String>

    @Published var selectedCategory:
        WorkoutCategory

    private let fetchWorkoutsUseCase:
        FetchWorkoutsUseCase
    private let preferenceStore:
        any WorkoutLauncherPreferenceStore

    init(
        fetchWorkoutsUseCase:
            FetchWorkoutsUseCase,
        initialCategory:
            WorkoutCategory = .strength,
        preferenceStore:
            any WorkoutLauncherPreferenceStore =
                UserDefaultsWorkoutLauncherPreferenceStore()
    ) {
        self.fetchWorkoutsUseCase =
            fetchWorkoutsUseCase
        self.selectedCategory =
            initialCategory
        self.preferenceStore =
            preferenceStore
        self.favoriteWorkoutIDs =
            preferenceStore
                .favoriteWorkoutIDs
    }

    var filteredWorkouts:
        [WorkoutDefinition] {
        workouts.filter {
            $0.category
                == selectedCategory
        }
    }

    func loadWorkouts() async {
        isLoading = true
        errorMessage = nil
        favoriteWorkoutIDs =
            preferenceStore
                .favoriteWorkoutIDs

        defer {
            isLoading = false
        }

        do {
            workouts =
                try await
                fetchWorkoutsUseCase
                    .execute()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    func isFavorite(
        _ workout: WorkoutDefinition
    ) -> Bool {
        favoriteWorkoutIDs
            .contains(
                workout.id
            )
    }

    func toggleFavorite(
        _ workout: WorkoutDefinition
    ) {
        let shouldFavorite =
            !isFavorite(workout)

        preferenceStore
            .setFavorite(
                shouldFavorite,
                workoutID:
                    workout.id
            )

        favoriteWorkoutIDs =
            preferenceStore
                .favoriteWorkoutIDs
    }
}
