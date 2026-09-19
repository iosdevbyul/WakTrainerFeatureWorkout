import Foundation
import WakTrainerDomainWorkout

@MainActor
final class WorkoutSelectionViewModel: ObservableObject {

    @Published private(set) var workouts: [WorkoutDefinition] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published var selectedCategory: WorkoutCategory = .strength

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase

    init(
        fetchWorkoutsUseCase: FetchWorkoutsUseCase
    ) {
        self.fetchWorkoutsUseCase = fetchWorkoutsUseCase
    }

    var filteredWorkouts: [WorkoutDefinition] {
        workouts.filter {
            $0.category == selectedCategory
        }
    }

    func loadWorkouts() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            workouts = try await fetchWorkoutsUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
