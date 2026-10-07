import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("WorkoutLauncherViewModel")
struct WorkoutLauncherViewModelTests {

    @Test("launcher toggles expanded state and resets cycling state when closed")
    func launcherExpansionState() {
        let viewModel = makeViewModel()

        viewModel.toggleLauncher()

        #expect(viewModel.isExpanded)
        #expect(!viewModel.isCyclingExpanded)

        viewModel.toggleCyclingOptions()

        #expect(viewModel.isCyclingExpanded)

        viewModel.toggleLauncher()

        #expect(!viewModel.isExpanded)
        #expect(!viewModel.isCyclingExpanded)
    }

    @Test("strength opens strength category selection")
    func strengthOpensStrengthSelection() {
        let viewModel = makeViewModel()

        viewModel.toggleLauncher()
        viewModel.openStrengthSelection()

        #expect(!viewModel.isExpanded)

        guard case .category(let category) =
                viewModel.destination else {
            Issue.record(
                "Expected strength category destination"
            )
            return
        }

        #expect(category == .strength)
    }

    @Test("running resolves catalog workout and opens workout flow")
    func runningResolvesWorkout() async {
        let viewModel = makeViewModel()

        await viewModel.openWorkout(
            .running
        )

        guard case .workout(let workout) =
                viewModel.destination else {
            Issue.record(
                "Expected running workout destination"
            )
            return
        }

        #expect(workout.id == "running")
        #expect(workout.category == .cardio)
        #expect(workout.type == .dynamicWorkout)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("cycling quick actions resolve indoor and outdoor workouts")
    func cyclingResolvesBothWorkoutTypes() async {
        let viewModel = makeViewModel()

        await viewModel.openWorkout(
            .indoorCycling
        )

        guard case .workout(let indoor) =
                viewModel.destination else {
            Issue.record(
                "Expected indoor cycling destination"
            )
            return
        }

        #expect(indoor.id == "indoor_cycling")
        #expect(indoor.type == .staticWorkout)

        viewModel.dismissWorkoutFlow()

        await viewModel.openWorkout(
            .outdoorCycling
        )

        guard case .workout(let outdoor) =
                viewModel.destination else {
            Issue.record(
                "Expected outdoor cycling destination"
            )
            return
        }

        #expect(outdoor.id == "outdoor_cycling")
        #expect(outdoor.type == .dynamicWorkout)
    }


    @Test("incomplete workout is exposed as a recovery destination")
    func incompleteWorkoutCanBeRecovered() async throws {
        let stored = makeStoredSession()
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                incomplete: [stored]
            )
        let viewModel = makeViewModel(
            sessionRepository: sessionRepository
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
        #expect(workout.category == .cardio)
        #expect(workout.type == .dynamicWorkout)
        #expect(recovered == stored)
    }

    @Test("discard removes the incomplete workout")
    func incompleteWorkoutCanBeDiscarded() async {
        let stored = makeStoredSession()
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                incomplete: [stored]
            )
        let viewModel = makeViewModel(
            sessionRepository: sessionRepository
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

    @Test("missing quick workout exposes launcher error")
    func missingWorkoutExposesError() async {
        let repository = LauncherMockWorkoutCatalogRepository(
            workouts: []
        )

        let viewModel = WorkoutLauncherViewModel(
            fetchWorkoutsUseCase: FetchWorkoutsUseCase(
                repository: repository
            )
        )

        await viewModel.openWorkout(
            .walking
        )

        #expect(viewModel.destination == nil)
        #expect(viewModel.errorMessage != nil)
    }
}

private extension WorkoutLauncherViewModelTests {

    func makeViewModel(
        sessionRepository:
            (any WorkoutSessionRepository)? = nil
    ) -> WorkoutLauncherViewModel {
        let workouts = [
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
                id: "indoor_cycling",
                name: "실내 자전거",
                category: .cardio,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "outdoor_cycling",
                name: "야외 자전거",
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

        let repository = LauncherMockWorkoutCatalogRepository(
            workouts: workouts
        )

        return WorkoutLauncherViewModel(
            fetchWorkoutsUseCase: FetchWorkoutsUseCase(
                repository: repository
            ),
            sessionRepository: sessionRepository
        )
    }

    func makeStoredSession() -> StoredWorkoutSession {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )
        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
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

    func fetchWorkouts() async throws -> [WorkoutDefinition] {
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
