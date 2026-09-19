import Foundation
import WakTrainerDomainWorkout

@MainActor
public final class WorkoutSelectionViewModel: ObservableObject {

    @Published public private(set) var workouts: [WorkoutDefinition] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    @Published public var selectedCategory: WorkoutCategory = .strength

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase

    public init(
        fetchWorkoutsUseCase: FetchWorkoutsUseCase
    ) {
        self.fetchWorkoutsUseCase = fetchWorkoutsUseCase
    }

    public var filteredWorkouts: [WorkoutDefinition] {
        workouts.filter {
            $0.category == selectedCategory
        }
    }

    public func loadWorkouts() async {
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
