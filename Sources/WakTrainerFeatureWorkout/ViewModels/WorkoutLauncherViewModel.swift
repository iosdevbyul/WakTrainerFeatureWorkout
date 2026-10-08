import Combine
import Foundation
import WakTrainerDomainWorkout

@MainActor
final class WorkoutLauncherViewModel: ObservableObject {

    enum Destination: Identifiable, Equatable {
        case workout(WorkoutDefinition)
        case catalog
        case recovered(
            WorkoutDefinition,
            StoredWorkoutSession
        )

        var id: String {
            switch self {
            case .workout(let workout):
                "workout-\(workout.id)"

            case .catalog:
                "catalog"

            case .recovered(_, let storedSession):
                "recovered-\(storedSession.session.id.uuidString)"
            }
        }
    }

    @Published var isExpanded = false
    @Published var destination: Destination?
    @Published var errorMessage: String?
    @Published var recoverableSession: StoredWorkoutSession?
    @Published var isRecoveryPromptPresented = false

    @Published private(set) var quickWorkouts:
        [WorkoutDefinition] = []
    @Published private(set) var isLoadingWorkouts = false

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase
    private let sessionRepository:
        (any WorkoutSessionRepository)?
    private let quickWorkoutLimit: Int

    init(
        fetchWorkoutsUseCase: FetchWorkoutsUseCase,
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        quickWorkoutLimit: Int = 4
    ) {
        self.fetchWorkoutsUseCase = fetchWorkoutsUseCase
        self.sessionRepository = sessionRepository
        self.quickWorkoutLimit = max(
            0,
            quickWorkoutLimit
        )
    }

    func loadWorkouts() async {
        guard !isLoadingWorkouts else {
            return
        }

        isLoadingWorkouts = true

        defer {
            isLoadingWorkouts = false
        }

        do {
            let workouts =
                try await fetchWorkoutsUseCase.execute()

            quickWorkouts =
                Array(
                    workouts.prefix(
                        quickWorkoutLimit
                    )
                )
        } catch {
            quickWorkouts = []
            errorMessage = error.localizedDescription
        }
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
    }

    func closeLauncher() {
        isExpanded = false
    }

    func openWorkout(
        _ workout: WorkoutDefinition
    ) {
        closeLauncher()
        destination = .workout(workout)
    }

    func openCatalog() {
        closeLauncher()
        destination = .catalog
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

    func makeWorkoutDefinition(
        from storedSession: StoredWorkoutSession
    ) throws -> WorkoutDefinition {
        let session = storedSession.session

        guard let category = WorkoutCategory(
            rawValue: session.workout.category
        ) else {
            throw WorkoutLauncherError
                .invalidStoredCategory(
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
    case invalidStoredCategory(String)

    var errorDescription: String? {
        switch self {
        case .invalidStoredCategory(
            let category
        ):
            "The saved workout category could not be restored: \(category)"
        }
    }
}
