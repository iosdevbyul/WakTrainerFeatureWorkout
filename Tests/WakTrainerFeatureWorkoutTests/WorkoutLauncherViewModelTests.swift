import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("WorkoutLauncherViewModel")
struct WorkoutLauncherViewModelTests {

    @Test("launcher toggles expanded state")
    func launcherExpansionState() {
        let viewModel = makeViewModel()

        viewModel.toggleLauncher()

        #expect(viewModel.isExpanded)

        viewModel.toggleLauncher()

        #expect(!viewModel.isExpanded)
    }

    @Test("quick start comes from the workout catalog")
    func quickStartUsesCatalogOrder() async {
        let viewModel = makeViewModel()

        await viewModel.loadWorkouts()

        #expect(
            viewModel.quickWorkouts.map(\.id)
                == [
                    "running",
                    "walking",
                    "swimming",
                    "squat"
                ]
        )
        #expect(!viewModel.isLoadingWorkouts)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("quick start limit is configurable")
    func quickStartRespectsLimit() async {
        let viewModel = makeViewModel(
            quickWorkoutLimit: 2
        )

        await viewModel.loadWorkouts()

        #expect(
            viewModel.quickWorkouts.map(\.id)
                == [
                    "running",
                    "walking"
                ]
        )
    }

    @Test("any catalog workout can open without launcher enum support")
    func arbitraryWorkoutOpensDirectly() async {
        let viewModel = makeViewModel()

        await viewModel.loadWorkouts()

        guard let swimming =
                viewModel.quickWorkouts.first(
                    where: {
                        $0.id == "swimming"
                    }
                ) else {
            Issue.record(
                "Expected swimming in quick workouts"
            )
            return
        }

        viewModel.openWorkout(
            swimming
        )

        guard case .workout(let workout) =
                viewModel.destination else {
            Issue.record(
                "Expected workout destination"
            )
            return
        }

        #expect(workout.id == "swimming")
        #expect(workout.name == "Swimming")
    }

    @Test("browse all opens workout catalog")
    func browseAllOpensCatalog() {
        let viewModel = makeViewModel()

        viewModel.toggleLauncher()
        viewModel.openCatalog()

        #expect(!viewModel.isExpanded)

        guard case .catalog =
                viewModel.destination else {
            Issue.record(
                "Expected catalog destination"
            )
            return
        }
    }

    @Test("incomplete workout is exposed as a recovery destination")
    func incompleteWorkoutCanBeRecovered()
        async throws {
        let stored = makeStoredSession()
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                incomplete: [stored]
            )
        let viewModel = makeViewModel(
            sessionRepository:
                sessionRepository
        )

        await viewModel.loadRecoverableWorkout()

        #expect(
            viewModel.recoverableSession
                == stored
        )
        #expect(
            viewModel.isRecoveryPromptPresented
        )

        viewModel.openRecoverableWorkout()

        guard case .recovered(
            let workout,
            let recovered
        ) = viewModel.destination else {
            Issue.record(
                "Expected recovered workout destination"
            )
            return
        }

        #expect(workout.id == "running")
        #expect(
            workout.category == .cardio
        )
        #expect(
            workout.type == .dynamicWorkout
        )
        #expect(recovered == stored)
    }

    @Test("discard removes the incomplete workout")
    func incompleteWorkoutCanBeDiscarded()
        async {
        let stored = makeStoredSession()
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                incomplete: [stored]
            )
        let viewModel = makeViewModel(
            sessionRepository:
                sessionRepository
        )

        await viewModel.loadRecoverableWorkout()
        await viewModel.discardRecoverableWorkout()

        #expect(
            sessionRepository.deletedIDs
                == [stored.session.id]
        )
        #expect(
            viewModel.recoverableSession == nil
        )
        #expect(
            !viewModel.isRecoveryPromptPresented
        )
    }
}

private extension WorkoutLauncherViewModelTests {

    func makeViewModel(
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        quickWorkoutLimit: Int = 4
    ) -> WorkoutLauncherViewModel {
        let workouts = [
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
                id: "swimming",
                name: "Swimming",
                category: .cardio,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "squat",
                name: "Squat",
                category: .strength,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "bench_press",
                name: "Bench Press",
                category: .strength,
                type: .staticWorkout
            )
        ]

        let repository =
            LauncherMockWorkoutCatalogRepository(
                workouts: workouts
            )

        return WorkoutLauncherViewModel(
            fetchWorkoutsUseCase:
                FetchWorkoutsUseCase(
                    repository: repository
                ),
            sessionRepository:
                sessionRepository,
            quickWorkoutLimit:
                quickWorkoutLimit
        )
    }

    func makeStoredSession()
        -> StoredWorkoutSession {
        let start = Date(
            timeIntervalSince1970:
                1_800_000_000
        )
        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "Running",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: nil,
                elapsedDuration: 300,
                activeDuration: 280,
                pausedDuration: 20
            )
        )

        return StoredWorkoutSession(
            session: session,
            persistenceState: .inProgress,
            syncState: .pending,
            updatedAt:
                start.addingTimeInterval(300)
        )
    }
}

private struct LauncherMockWorkoutCatalogRepository:
    WorkoutCatalogRepository {

    let workouts: [WorkoutDefinition]

    func fetchWorkouts() async throws
        -> [WorkoutDefinition] {
        workouts
    }
}

@MainActor
private final class LauncherMockWorkoutSessionRepository:
    WorkoutSessionRepository {

    private var incomplete:
        [StoredWorkoutSession]
    private(set) var deletedIDs: [UUID] = []

    init(
        incomplete: [StoredWorkoutSession]
    ) {
        self.incomplete = incomplete
    }

    func saveCheckpoint(
        _ session: WorkoutSession
    ) async throws {}

    func saveCompleted(
        _ session: WorkoutSession
    ) async throws {}

    func fetchSession(
        id: UUID
    ) async throws -> StoredWorkoutSession? {
        incomplete.first {
            $0.session.id == id
        }
    }

    func fetchSessions()
        async throws -> [StoredWorkoutSession] {
        incomplete
    }

    func fetchIncompleteSessions()
        async throws -> [StoredWorkoutSession] {
        incomplete
    }

    func fetchCompletedSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [StoredWorkoutSession] {
        []
    }

    func deleteSession(
        id: UUID
    ) async throws {
        deletedIDs.append(id)
        incomplete.removeAll {
            $0.session.id == id
        }
    }

    func deleteAllSessions() async throws {
        incomplete.removeAll()
    }
}
