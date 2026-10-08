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

    @Test("catalog order is used before personalization exists")
    func catalogFallback() async {
        let viewModel = makeViewModel()

        await viewModel.loadWorkouts()

        #expect(
            viewModel
                .quickStartItems
                .map { $0.workout.id }
                == [
                    "running",
                    "walking",
                    "swimming",
                    "squat"
                ]
        )
        #expect(
            viewModel
                .quickStartItems
                .allSatisfy {
                    $0.source == .catalog
                }
        )
    }

    @Test("favorites are ranked before usage and catalog defaults")
    func favoritesRankFirst() async {
        let preferences =
            LauncherTestPreferenceStore(
                favorites: [
                    "bench_press"
                ]
            )
        let viewModel =
            makeViewModel(
                preferenceStore:
                    preferences
            )

        await viewModel.loadWorkouts()

        #expect(
            viewModel
                .quickStartItems
                .first?
                .workout.id
                == "bench_press"
        )
        #expect(
            viewModel
                .quickStartItems
                .first?
                .source
                == .favorite
        )
    }

    @Test("frequent and recent workouts personalize quick start")
    func usagePersonalizesQuickStart() async {
        let now = Date(
            timeIntervalSince1970:
                1_900_000_000
        )
        let sessions = [
            makeCompletedSession(
                workoutID:
                    "bench_press",
                name:
                    "Bench Press",
                date:
                    now
                        .addingTimeInterval(
                            -3_600
                        )
            ),
            makeCompletedSession(
                workoutID:
                    "bench_press",
                name:
                    "Bench Press",
                date:
                    now
                        .addingTimeInterval(
                            -7_200
                        )
            ),
            makeCompletedSession(
                workoutID:
                    "bench_press",
                name:
                    "Bench Press",
                date:
                    now
                        .addingTimeInterval(
                            -10_800
                        )
            ),
            makeCompletedSession(
                workoutID:
                    "walking",
                name:
                    "Walking",
                date: now
            )
        ]
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                completed: sessions
            )
        let viewModel =
            makeViewModel(
                sessionRepository:
                    sessionRepository
            )

        await viewModel.loadWorkouts()

        #expect(
            viewModel
                .quickStartItems[0]
                .workout.id
                == "bench_press"
        )
        #expect(
            viewModel
                .quickStartItems[0]
                .source
                == .frequent
        )
        #expect(
            viewModel
                .quickStartItems[1]
                .workout.id
                == "walking"
        )
        #expect(
            viewModel
                .quickStartItems[1]
                .source
                == .recent
        )
    }

    @Test("quick start limit is configurable")
    func quickStartRespectsLimit() async {
        let viewModel =
            makeViewModel(
                quickWorkoutLimit: 2
            )

        await viewModel.loadWorkouts()

        #expect(
            viewModel
                .quickStartItems
                .count
                == 2
        )
    }

    @Test("any catalog workout can open directly")
    func arbitraryWorkoutOpensDirectly() async {
        let viewModel = makeViewModel()

        await viewModel.loadWorkouts()

        guard let swimming =
                viewModel
                    .quickStartItems
                    .first(
                        where: {
                            $0.workout.id
                                == "swimming"
                        }
                    )?
                    .workout else {
            Issue.record(
                "Expected swimming in quick start"
            )
            return
        }

        viewModel.openWorkout(
            swimming
        )

        guard case .workout(
            let workout
        ) = viewModel.destination else {
            Issue.record(
                "Expected workout destination"
            )
            return
        }

        #expect(
            workout.id
                == "swimming"
        )
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
        let stored =
            makeStoredSession()
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                incomplete: [
                    stored
                ]
            )
        let viewModel =
            makeViewModel(
                sessionRepository:
                    sessionRepository
            )

        await viewModel
            .loadRecoverableWorkout()

        #expect(
            viewModel
                .recoverableSession
                == stored
        )
        #expect(
            viewModel
                .isRecoveryPromptPresented
        )

        viewModel
            .openRecoverableWorkout()

        guard case .recovered(
            let workout,
            let recovered
        ) = viewModel.destination else {
            Issue.record(
                "Expected recovered workout destination"
            )
            return
        }

        #expect(
            workout.id == "running"
        )
        #expect(recovered == stored)
    }

    @Test("discard removes the incomplete workout")
    func incompleteWorkoutCanBeDiscarded()
        async {
        let stored =
            makeStoredSession()
        let sessionRepository =
            LauncherMockWorkoutSessionRepository(
                incomplete: [
                    stored
                ]
            )
        let viewModel =
            makeViewModel(
                sessionRepository:
                    sessionRepository
            )

        await viewModel
            .loadRecoverableWorkout()
        await viewModel
            .discardRecoverableWorkout()

        #expect(
            sessionRepository
                .deletedIDs
                == [
                    stored.session.id
                ]
        )
        #expect(
            viewModel
                .recoverableSession
                == nil
        )
    }
}

private extension WorkoutLauncherViewModelTests {

    func makeViewModel(
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        preferenceStore:
            any WorkoutLauncherPreferenceStore =
                LauncherTestPreferenceStore(),
        quickWorkoutLimit:
            Int = 4
    ) -> WorkoutLauncherViewModel {
        let repository =
            LauncherMockWorkoutCatalogRepository(
                workouts:
                    makeWorkouts()
            )

        return WorkoutLauncherViewModel(
            fetchWorkoutsUseCase:
                FetchWorkoutsUseCase(
                    repository:
                        repository
                ),
            sessionRepository:
                sessionRepository,
            preferenceStore:
                preferenceStore,
            quickWorkoutLimit:
                quickWorkoutLimit
        )
    }

    func makeWorkouts()
        -> [WorkoutDefinition] {
        [
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
    }

    func makeCompletedSession(
        workoutID: String,
        name: String,
        date: Date
    ) -> StoredWorkoutSession {
        let session =
            WorkoutSession(
                workout:
                    WorkoutIdentity(
                        workoutID:
                            workoutID,
                        name: name,
                        category:
                            "strength",
                        type:
                            .staticWorkout
                    ),
                timing:
                    WorkoutTiming(
                        startDate:
                            date
                                .addingTimeInterval(
                                    -1_800
                                ),
                        endDate: date,
                        elapsedDuration:
                            1_800,
                        activeDuration:
                            1_800
                    )
            )

        return StoredWorkoutSession(
            session: session,
            persistenceState:
                .completed,
            syncState: .synced,
            updatedAt: date
        )
    }

    func makeStoredSession()
        -> StoredWorkoutSession {
        let start =
            Date(
                timeIntervalSince1970:
                    1_800_000_000
            )
        let session =
            WorkoutSession(
                workout:
                    WorkoutIdentity(
                        workoutID:
                            "running",
                        name: "Running",
                        category:
                            "cardio",
                        type:
                            .dynamicWorkout
                    ),
                timing:
                    WorkoutTiming(
                        startDate:
                            start,
                        endDate: nil,
                        elapsedDuration:
                            300,
                        activeDuration:
                            280,
                        pausedDuration:
                            20
                    )
            )

        return StoredWorkoutSession(
            session: session,
            persistenceState:
                .inProgress,
            syncState: .pending,
            updatedAt:
                start
                    .addingTimeInterval(
                        300
                    )
        )
    }
}

private struct LauncherMockWorkoutCatalogRepository:
    WorkoutCatalogRepository {

    let workouts:
        [WorkoutDefinition]

    func fetchWorkouts() async throws
        -> [WorkoutDefinition] {
        workouts
    }
}

private final class LauncherTestPreferenceStore:
    WorkoutLauncherPreferenceStore,
    @unchecked Sendable {

    private(set) var favoriteWorkoutIDs:
        Set<String>

    init(
        favorites:
            Set<String> = []
    ) {
        favoriteWorkoutIDs =
            favorites
    }

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

@MainActor
private final class LauncherMockWorkoutSessionRepository:
    WorkoutSessionRepository {

    private var incomplete:
        [StoredWorkoutSession]
    private var completed:
        [StoredWorkoutSession]
    private(set) var deletedIDs:
        [UUID] = []

    init(
        incomplete:
            [StoredWorkoutSession] = [],
        completed:
            [StoredWorkoutSession] = []
    ) {
        self.incomplete =
            incomplete
        self.completed =
            completed
    }

    func saveCheckpoint(
        _ session: WorkoutSession
    ) async throws {}

    func saveCompleted(
        _ session: WorkoutSession
    ) async throws {}

    func fetchSession(
        id: UUID
    ) async throws
        -> StoredWorkoutSession? {
        (
            incomplete + completed
        )
        .first {
            $0.session.id == id
        }
    }

    func fetchSessions()
        async throws
        -> [StoredWorkoutSession] {
        incomplete + completed
    }

    func fetchIncompleteSessions()
        async throws
        -> [StoredWorkoutSession] {
        incomplete
    }

    func fetchCompletedSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws
        -> [StoredWorkoutSession] {
        completed.filter {
            let date =
                $0.session
                    .timing
                    .endDate
                ?? $0.updatedAt

            return date >= startDate
                && date < endDate
        }
    }

    func deleteSession(
        id: UUID
    ) async throws {
        deletedIDs.append(id)
        incomplete.removeAll {
            $0.session.id == id
        }
        completed.removeAll {
            $0.session.id == id
        }
    }

    func deleteAllSessions()
        async throws {
        incomplete.removeAll()
        completed.removeAll()
    }
}
