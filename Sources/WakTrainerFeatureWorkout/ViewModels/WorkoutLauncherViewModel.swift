import Combine
import Foundation
import WakTrainerDomainWorkout

struct WorkoutQuickStartItem:
    Identifiable,
    Equatable,
    Sendable {

    enum Source:
        Equatable,
        Sendable {
        case favorite
        case frequent
        case recent
        case catalog
    }

    let workout: WorkoutDefinition
    let source: Source

    var id: String {
        workout.id
    }
}

@MainActor
final class WorkoutLauncherViewModel:
    ObservableObject {

    enum Destination:
        Identifiable,
        Equatable {
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

            case .recovered(
                _,
                let storedSession
            ):
                "recovered-\(storedSession.session.id.uuidString)"
            }
        }
    }

    @Published var isExpanded = false
    @Published var destination: Destination?
    @Published var errorMessage: String?
    @Published var recoverableSession:
        StoredWorkoutSession?
    @Published var isRecoveryPromptPresented = false

    @Published private(set) var quickStartItems:
        [WorkoutQuickStartItem] = []
    @Published private(set) var isLoadingWorkouts = false

    private let fetchWorkoutsUseCase:
        FetchWorkoutsUseCase
    private let sessionRepository:
        (any WorkoutSessionRepository)?
    private let preferenceStore:
        any WorkoutLauncherPreferenceStore
    private let quickWorkoutLimit: Int

    init(
        fetchWorkoutsUseCase:
            FetchWorkoutsUseCase,
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        preferenceStore:
            any WorkoutLauncherPreferenceStore =
                UserDefaultsWorkoutLauncherPreferenceStore(),
        quickWorkoutLimit: Int = 4
    ) {
        self.fetchWorkoutsUseCase =
            fetchWorkoutsUseCase
        self.sessionRepository =
            sessionRepository
        self.preferenceStore =
            preferenceStore
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
                try await fetchWorkoutsUseCase
                    .execute()

            let completedSessions =
                await loadCompletedSessions()

            quickStartItems =
                makeQuickStartItems(
                    workouts: workouts,
                    completedSessions:
                        completedSessions
                )
        } catch {
            quickStartItems = []
            errorMessage =
                error.localizedDescription
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

            recoverableSession =
                incomplete.first
            isRecoveryPromptPresented =
                recoverableSession != nil
        } catch {
            errorMessage =
                error.localizedDescription
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
            let workout =
                try makeWorkoutDefinition(
                    from: recoverableSession
                )

            isRecoveryPromptPresented = false
            closeLauncher()

            destination = .recovered(
                workout,
                recoverableSession
            )
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    func discardRecoverableWorkout() async {
        guard let recoverableSession,
              let sessionRepository else {
            return
        }

        do {
            try await sessionRepository
                .deleteSession(
                    id:
                        recoverableSession
                            .session.id
                )

            self.recoverableSession = nil
            isRecoveryPromptPresented = false

            let remaining =
                try await sessionRepository
                    .fetchIncompleteSessions()

            self.recoverableSession =
                remaining.first
        } catch {
            errorMessage =
                error.localizedDescription
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

    struct WorkoutUsage {
        var count = 0
        var lastUsedAt: Date?
    }

    func loadCompletedSessions() async
        -> [StoredWorkoutSession] {
        guard let sessionRepository else {
            return []
        }

        guard let sessions =
                try? await sessionRepository
                    .fetchSessions() else {
            return []
        }

        return sessions.filter {
            $0.persistenceState
                == .completed
        }
    }

    func makeQuickStartItems(
        workouts: [WorkoutDefinition],
        completedSessions:
            [StoredWorkoutSession]
    ) -> [WorkoutQuickStartItem] {
        let favoriteIDs =
            preferenceStore
                .favoriteWorkoutIDs
        let usage =
            makeUsage(
                from: completedSessions
            )
        let catalogOrder =
            Dictionary(
                uniqueKeysWithValues:
                    workouts.enumerated().map {
                        ($0.element.id, $0.offset)
                    }
            )

        return workouts
            .sorted { lhs, rhs in
                compare(
                    lhs,
                    rhs,
                    favoriteIDs:
                        favoriteIDs,
                    usage: usage,
                    catalogOrder:
                        catalogOrder
                )
            }
            .prefix(quickWorkoutLimit)
            .map { workout in
                WorkoutQuickStartItem(
                    workout: workout,
                    source:
                        source(
                            for: workout.id,
                            favoriteIDs:
                                favoriteIDs,
                            usage: usage
                        )
                )
            }
    }

    func makeUsage(
        from sessions:
            [StoredWorkoutSession]
    ) -> [String: WorkoutUsage] {
        var result:
            [String: WorkoutUsage] = [:]

        for stored in sessions {
            let id =
                stored.session
                    .workout.workoutID
            let usedAt =
                stored.session
                    .timing.endDate
                ?? stored.updatedAt

            var current =
                result[id]
                ?? WorkoutUsage()
            current.count += 1

            if current.lastUsedAt == nil
                || usedAt
                    > current.lastUsedAt! {
                current.lastUsedAt =
                    usedAt
            }

            result[id] = current
        }

        return result
    }

    func compare(
        _ lhs: WorkoutDefinition,
        _ rhs: WorkoutDefinition,
        favoriteIDs: Set<String>,
        usage: [String: WorkoutUsage],
        catalogOrder: [String: Int]
    ) -> Bool {
        let lhsFavorite =
            favoriteIDs.contains(lhs.id)
        let rhsFavorite =
            favoriteIDs.contains(rhs.id)

        if lhsFavorite != rhsFavorite {
            return lhsFavorite
        }

        let lhsUsage =
            usage[lhs.id]
            ?? WorkoutUsage()
        let rhsUsage =
            usage[rhs.id]
            ?? WorkoutUsage()

        if lhsUsage.count
            != rhsUsage.count {
            return lhsUsage.count
                > rhsUsage.count
        }

        if lhsUsage.lastUsedAt
            != rhsUsage.lastUsedAt {
            return (
                lhsUsage.lastUsedAt
                ?? .distantPast
            ) > (
                rhsUsage.lastUsedAt
                ?? .distantPast
            )
        }

        return (
            catalogOrder[lhs.id]
            ?? .max
        ) < (
            catalogOrder[rhs.id]
            ?? .max
        )
    }

    func source(
        for workoutID: String,
        favoriteIDs: Set<String>,
        usage: [String: WorkoutUsage]
    ) -> WorkoutQuickStartItem.Source {
        if favoriteIDs.contains(
            workoutID
        ) {
            return .favorite
        }

        let count =
            usage[workoutID]?.count
            ?? 0

        if count >= 2 {
            return .frequent
        }

        if count == 1 {
            return .recent
        }

        return .catalog
    }

    func makeWorkoutDefinition(
        from storedSession:
            StoredWorkoutSession
    ) throws -> WorkoutDefinition {
        let session =
            storedSession.session

        guard let category =
                WorkoutCategory(
                    rawValue:
                        session.workout
                            .category
                ) else {
            throw WorkoutLauncherError
                .invalidStoredCategory(
                    session.workout
                        .category
                )
        }

        return WorkoutDefinition(
            id:
                session.workout
                    .workoutID,
            name:
                session.workout.name,
            category: category,
            type:
                session.workout.type
        )
    }
}

private enum WorkoutLauncherError:
    LocalizedError {
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
