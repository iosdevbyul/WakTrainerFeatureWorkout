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
        case recovered(
            WorkoutDefinition,
            StoredWorkoutSession
        )

        var id: String {
            switch self {
            case .workout(let workout):
                "workout-\(workout.id)"

            case .category(let category):
                "category-\(category.rawValue)"

            case .recovered(_, let storedSession):
                "recovered-\(storedSession.session.id.uuidString)"
            }
        }
    }

    @Published var isExpanded = false
    @Published var isCyclingExpanded = false
    @Published var destination: Destination?
    @Published var errorMessage: String?
    @Published var recoverableSession: StoredWorkoutSession?
    @Published var isRecoveryPromptPresented = false

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase
    private let sessionRepository: (any WorkoutSessionRepository)?
    private var cachedWorkouts: [WorkoutDefinition] = []

    init(
        fetchWorkoutsUseCase: FetchWorkoutsUseCase,
        sessionRepository: (any WorkoutSessionRepository)? = nil
    ) {
        self.fetchWorkoutsUseCase = fetchWorkoutsUseCase
        self.sessionRepository = sessionRepository
    }

    func loadRecoverableWorkout() async {
        guard destination == nil,
              let sessionRepository else {
            return
        }

        do {
            let incomplete =
                try await sessionRepository
                    .fetchIncompleteSessions()

            recoverableSession = incomplete.first
            isRecoveryPromptPresented =
                recoverableSession != nil
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func openRecoverableWorkout() {
        guard let recoverableSession else {
            return
        }

        do {
            let workout = try makeWorkoutDefinition(
                from: recoverableSession
            )

            isRecoveryPromptPresented = false
            closeLauncher()

            destination = .recovered(
                workout,
                recoverableSession
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardRecoverableWorkout() async {
        guard let recoverableSession,
              let sessionRepository else {
            return
        }

        do {
            try await sessionRepository.deleteSession(
                id: recoverableSession.session.id
            )

            self.recoverableSession = nil
            isRecoveryPromptPresented = false

            let remaining =
                try await sessionRepository
                    .fetchIncompleteSessions()

            self.recoverableSession =
                remaining.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissRecoveryPrompt() {
        isRecoveryPromptPresented = false
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

    func makeWorkoutDefinition(
        from storedSession: StoredWorkoutSession
    ) throws -> WorkoutDefinition {
        let session = storedSession.session

        guard let category = WorkoutCategory(
            rawValue: session.workout.category
        ) else {
            throw WorkoutLauncherError.invalidStoredCategory(
                session.workout.category
            )
        }

        return WorkoutDefinition(
            id: session.workout.workoutID,
            name: session.workout.name,
            category: category,
            type: session.workout.type
        )
    }
}

private enum WorkoutLauncherError: LocalizedError {
    case workoutNotFound(String)
    case invalidStoredCategory(String)

    var errorDescription: String? {
        switch self {
        case .workoutNotFound(let id):
            "운동 정보를 찾을 수 없습니다: \(id)"

        case .invalidStoredCategory(let category):
            "저장된 운동 종류를 복구할 수 없습니다: \(category)"
        }
    }
}
