import Combine
import Foundation
import WakTrainerDomainWorkout

@MainActor
final class WorkoutLauncherViewModel: ObservableObject {

    enum QuickWorkout: String, Sendable {
        case running = "running"
        case walking = "walking"
        case indoorCycling = "indoor_cycling"
        case outdoorCycling = "outdoor_cycling"
    }

    enum Destination: Identifiable, Equatable {
        case workout(WorkoutDefinition)
        case category(WorkoutCategory)

        var id: String {
            switch self {
            case .workout(let workout):
                "workout-\(workout.id)"

            case .category(let category):
                "category-\(category.rawValue)"
            }
        }
    }

    @Published var isExpanded = false
    @Published var isCyclingExpanded = false
    @Published var destination: Destination?
    @Published var errorMessage: String?

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase
    private var cachedWorkouts: [WorkoutDefinition] = []

    init(
        fetchWorkoutsUseCase: FetchWorkoutsUseCase
    ) {
        self.fetchWorkoutsUseCase = fetchWorkoutsUseCase
    }

    func toggleLauncher() {
        isExpanded.toggle()

        if !isExpanded {
            isCyclingExpanded = false
        }
    }

    func closeLauncher() {
        isExpanded = false
        isCyclingExpanded = false
    }

    func toggleCyclingOptions() {
        isCyclingExpanded.toggle()
    }

    func openStrengthSelection() {
        closeLauncher()
        destination = .category(.strength)
    }

    func openWorkout(
        _ quickWorkout: QuickWorkout
    ) async {
        do {
            let workout = try await resolveWorkout(
                quickWorkout
            )

            closeLauncher()
            destination = .workout(workout)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissWorkoutFlow() {
        destination = nil
    }
}

private extension WorkoutLauncherViewModel {

    func resolveWorkout(
        _ quickWorkout: QuickWorkout
    ) async throws -> WorkoutDefinition {
        if cachedWorkouts.isEmpty {
            cachedWorkouts =
                try await fetchWorkoutsUseCase.execute()
        }

        guard let workout = cachedWorkouts.first(
            where: {
                $0.id == quickWorkout.rawValue
            }
        ) else {
            throw WorkoutLauncherError.workoutNotFound(
                quickWorkout.rawValue
            )
        }

        return workout
    }
}

private enum WorkoutLauncherError: LocalizedError {
    case workoutNotFound(String)

    var errorDescription: String? {
        switch self {
        case .workoutNotFound(let id):
            "운동 정보를 찾을 수 없습니다: \(id)"
        }
    }
}
