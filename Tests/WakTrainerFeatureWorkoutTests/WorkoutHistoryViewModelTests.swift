import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("WorkoutHistoryViewModel")
struct WorkoutHistoryViewModelTests {

    @Test("selected date queries the exact calendar day")
    func selectedDateUsesDayRange() async throws {
        var calendar = Calendar(
            identifier: .gregorian
        )
        calendar.timeZone =
            TimeZone(secondsFromGMT: 0)!

        let selectedDate = Date(
            timeIntervalSince1970:
                1_800_000_000
        )
        let startDate =
            calendar.startOfDay(
                for: selectedDate
            )
        let endDate = try #require(
            calendar.date(
                byAdding: .day,
                value: 1,
                to: startDate
            )
        )

        let first = makeStoredSession(
            startedAt:
                startDate
                    .addingTimeInterval(3_600)
        )
        let second = makeStoredSession(
            id: UUID(),
            startedAt:
                startDate
                    .addingTimeInterval(7_200)
        )

        let repository =
            HistoryMockWorkoutSessionRepository(
                completedInRange:
                    [first, second]
            )

        let viewModel =
            WorkoutHistoryViewModel(
                sessionRepository:
                    repository
            )

        await viewModel.load(
            selectedDate: selectedDate,
            calendar: calendar
        )

        #expect(
            repository.requestedRanges.count
                == 1
        )
        #expect(
            repository.requestedRanges
                .first?.0 == startDate
        )
        #expect(
            repository.requestedRanges
                .first?.1 == endDate
        )
        #expect(
            viewModel.sessions
                == [first, second]
        )
        #expect(viewModel.errorMessage == nil)
    }

    @Test("all history keeps completed sessions and orders newest first")
    func allHistoryFiltersAndSorts() async {
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
            HistoryMockWorkoutSessionRepository(
                allSessions: [
                    older,
                    incomplete,
                    newer
                ]
            )

        let viewModel =
            WorkoutHistoryViewModel(
                sessionRepository:
                    repository
            )

        await viewModel.load(
            selectedDate: nil
        )

        #expect(
            viewModel.sessions
                == [newer, older]
        )
    }

    @Test("missing storage exposes an English error")
    func missingStorageExposesError() async {
        let viewModel =
            WorkoutHistoryViewModel(
                sessionRepository: nil
            )

        await viewModel.load(
            selectedDate: nil
        )

        #expect(viewModel.sessions.isEmpty)
        #expect(
            viewModel.errorMessage
                == "Workout history storage is unavailable."
        )
    }
}

private extension WorkoutHistoryViewModelTests {

    func makeStoredSession(
        id: UUID = UUID(),
        startedAt: Date,
        persistenceState:
            WorkoutSessionPersistenceState =
                .completed
    ) -> StoredWorkoutSession {
        let session = WorkoutSession(
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
                        .addingTimeInterval(1_800)
                    : nil,
                elapsedDuration: 1_800,
                activeDuration: 1_700,
                pausedDuration: 100
            ),
            health: WorkoutHealthData(
                summary:
                    WorkoutHealthSummary(
                        activeCalories: 250,
                        distanceMeters: 5_000
                    )
            )
        )

        return StoredWorkoutSession(
            session: session,
            persistenceState:
                persistenceState,
            syncState: .pending,
            updatedAt:
                startedAt
                    .addingTimeInterval(1_800)
        )
    }
}

@MainActor
private final class HistoryMockWorkoutSessionRepository:
    WorkoutSessionRepository {

    var allSessions:
        [StoredWorkoutSession]
    var completedInRange:
        [StoredWorkoutSession]
    private(set) var requestedRanges:
        [(Date, Date)] = []

    init(
        allSessions:
            [StoredWorkoutSession] = [],
        completedInRange:
            [StoredWorkoutSession] = []
    ) {
        self.allSessions = allSessions
        self.completedInRange =
            completedInRange
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
        allSessions.first {
            $0.session.id == id
        }
    }

    func fetchSessions()
        async throws -> [StoredWorkoutSession] {
        allSessions
    }

    func fetchIncompleteSessions()
        async throws -> [StoredWorkoutSession] {
        allSessions.filter {
            $0.persistenceState == .inProgress
        }
    }

    func fetchCompletedSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [StoredWorkoutSession] {
        requestedRanges.append(
            (startDate, endDate)
        )
        return completedInRange
    }

    func deleteSession(
        id: UUID
    ) async throws {}

    func deleteAllSessions() async throws {}
}
