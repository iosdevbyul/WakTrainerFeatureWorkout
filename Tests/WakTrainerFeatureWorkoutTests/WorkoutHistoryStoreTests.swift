import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("WorkoutHistoryStore")
struct WorkoutHistoryStoreTests {

    @Test("reload keeps only completed sessions and sorts newest first")
    func reloadFiltersAndSorts() async {
        let older = makeStoredSession(
            startedAt: Date(
                timeIntervalSince1970:
                    1_800_000_000
            )
        )
        let newer = makeStoredSession(
            id: UUID(),
            startedAt: Date(
                timeIntervalSince1970:
                    1_800_010_000
            )
        )
        let incomplete = makeStoredSession(
            id: UUID(),
            startedAt: Date(
                timeIntervalSince1970:
                    1_800_020_000
            ),
            persistenceState:
                .inProgress
        )

        let repository =
            HistoryStoreMockRepository(
                sessions: [
                    older,
                    incomplete,
                    newer
                ]
            )

        let store = WorkoutHistoryStore(
            repositoryProvider: {
                repository
            }
        )

        await store.reload()

        #expect(
            store.sessions
                == [newer, older]
        )
        #expect(
            store.latestSession?.id
                == newer.session.id
        )
        #expect(store.errorMessage == nil)
    }

    @Test("highlighted dates use calendar start of day")
    func highlightedDatesUseStartOfDay() async {
        var calendar = Calendar(
            identifier: .gregorian
        )
        calendar.timeZone =
            TimeZone(secondsFromGMT: 0)!

        let firstDate = Date(
            timeIntervalSince1970:
                1_800_000_000
        )
        let secondSameDay =
            firstDate.addingTimeInterval(600)
        let nextDay =
            firstDate.addingTimeInterval(
                86_400
            )

        let repository =
            HistoryStoreMockRepository(
                sessions: [
                    makeStoredSession(
                        startedAt: firstDate
                    ),
                    makeStoredSession(
                        id: UUID(),
                        startedAt:
                            secondSameDay
                    ),
                    makeStoredSession(
                        id: UUID(),
                        startedAt: nextDay
                    )
                ]
            )

        let store = WorkoutHistoryStore(
            repositoryProvider: {
                repository
            }
        )

        await store.reload()

        let highlighted =
            store.highlightedDates(
                calendar: calendar
            )

        #expect(highlighted.count == 2)
        #expect(
            highlighted.contains(
                calendar.startOfDay(
                    for: firstDate
                )
            )
        )
        #expect(
            highlighted.contains(
                calendar.startOfDay(
                    for: nextDay
                )
            )
        )
    }
}

private extension WorkoutHistoryStoreTests {

    func makeStoredSession(
        id: UUID = UUID(),
        startedAt: Date,
        persistenceState:
            WorkoutSessionPersistenceState =
                .completed
    ) -> StoredWorkoutSession {
        StoredWorkoutSession(
            session: WorkoutSession(
                id: id,
                workout: WorkoutIdentity(
                    workoutID: "running",
                    name: "Running",
                    category: "cardio",
                    type: .dynamicWorkout
                ),
                timing: WorkoutTiming(
                    startDate: startedAt,
                    endDate:
                        persistenceState
                            == .completed
                        ? startedAt
                            .addingTimeInterval(600)
                        : nil,
                    elapsedDuration: 600,
                    activeDuration: 580,
                    pausedDuration: 20
                )
            ),
            persistenceState:
                persistenceState,
            syncState: .pending,
            updatedAt:
                startedAt
                    .addingTimeInterval(600)
        )
    }
}

@MainActor
private final class HistoryStoreMockRepository:
    WorkoutSessionRepository {

    let sessions: [StoredWorkoutSession]

    init(
        sessions: [StoredWorkoutSession]
    ) {
        self.sessions = sessions
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
        sessions.first {
            $0.session.id == id
        }
    }

    func fetchSessions()
        async throws -> [StoredWorkoutSession] {
        sessions
    }

    func fetchIncompleteSessions()
        async throws -> [StoredWorkoutSession] {
        sessions.filter {
            $0.persistenceState == .inProgress
        }
    }

    func fetchCompletedSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [StoredWorkoutSession] {
        sessions.filter {
            $0.persistenceState == .completed &&
            $0.session.timing.startDate >= startDate &&
            $0.session.timing.startDate < endDate
        }
    }

    func deleteSession(
        id: UUID
    ) async throws {}

    func deleteAllSessions() async throws {}
}
