import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("WorkoutHistoryViewModel")
struct WorkoutHistoryViewModelTests {

    @Test("selected date filters the exact calendar day")
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
        let previousDay = makeStoredSession(
            id: UUID(),
            startedAt:
                startDate
                    .addingTimeInterval(-3_600)
        )
        let nextDay = makeStoredSession(
            id: UUID(),
            startedAt:
                startDate
                    .addingTimeInterval(86_400)
        )
        let incomplete = makeStoredSession(
            id: UUID(),
            startedAt:
                startDate
                    .addingTimeInterval(4_500),
            persistenceState:
                .inProgress
        )

        let repository =
            HistoryMockWorkoutSessionRepository(
                allSessions: [
                    nextDay,
                    incomplete,
                    second,
                    previousDay,
                    first
                ]
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
            viewModel.sessions
                == [first, second]
        )
        #expect(viewModel.errorMessage == nil)
    }

    @Test("selected day follows viewer timezone without rewriting session timestamp")
    func selectedDayFollowsViewerTimezone() async throws {
        let instant = try #require(
            ISO8601DateFormatter().date(from: "2026-10-24T23:00:00Z")
        )
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let vancouver = try #require(TimeZone(identifier: "America/Vancouver"))
        var koreanCalendar = Calendar(identifier: .gregorian)
        koreanCalendar.timeZone = seoul
        var canadianCalendar = Calendar(identifier: .gregorian)
        canadianCalendar.timeZone = vancouver

        let workout = makeStoredSession(startedAt: instant)
        let repository = HistoryMockWorkoutSessionRepository(allSessions: [workout])
        let viewModel = WorkoutHistoryViewModel(sessionRepository: repository)

        await viewModel.load(selectedDate: instant, calendar: koreanCalendar)
        #expect(viewModel.sessions == [workout])

        let nextCanadianDay = try #require(canadianCalendar.date(
            byAdding: .day,
            value: 1,
            to: canadianCalendar.startOfDay(for: instant)
        ))
        await viewModel.load(selectedDate: nextCanadianDay, calendar: canadianCalendar)
        #expect(viewModel.sessions.isEmpty)

        let canadianDay = canadianCalendar.startOfDay(for: instant)
        await viewModel.load(selectedDate: canadianDay, calendar: canadianCalendar)
        #expect(viewModel.sessions == [workout])
        #expect(viewModel.sessions.first?.session.timing.startDate == instant)
    }

    @Test("selected day uses DST-aware calendar boundaries")
    func selectedDayUsesDSTBoundaries() async throws {
        let zone = try #require(TimeZone(identifier: "America/Vancouver"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let selectedDay = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 8)
        ))
        let nextDay = try #require(calendar.date(
            byAdding: .day, value: 1, to: selectedDay
        ))
        #expect(nextDay.timeIntervalSince(selectedDay) == 23 * 3600)

        let inside = makeStoredSession(
            startedAt: nextDay.addingTimeInterval(-60)
        )
        let outside = makeStoredSession(
            id: UUID(), startedAt: nextDay
        )
        let repository = HistoryMockWorkoutSessionRepository(
            allSessions: [inside, outside]
        )
        let viewModel = WorkoutHistoryViewModel(sessionRepository: repository)
        await viewModel.load(selectedDate: selectedDay, calendar: calendar)
        #expect(viewModel.sessions == [inside])
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

    @Test("reloading history reflects a persisted Restore and Undo snapshot")
    func reloadReflectsUpdatedStoredSession() async {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let original = makeStoredSession(startedAt: startedAt)
        let repository = HistoryMockWorkoutSessionRepository(allSessions: [original])
        let model = WorkoutHistoryViewModel(sessionRepository: repository)

        await model.load(selectedDate: nil)
        #expect(model.sessions.first?.session.timing.activeDuration == 1700)

        var restored = original
        restored.session.timing.activeDuration = 1750
        restored.session.timing.pausedDuration = 50
        repository.allSessions = [restored]

        await model.load(selectedDate: nil)
        #expect(model.sessions == [restored])

        repository.allSessions = [original]
        await model.load(selectedDate: nil)
        #expect(model.sessions == [original])
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

    init(
        allSessions:
            [StoredWorkoutSession] = []
    ) {
        self.allSessions = allSessions
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
        allSessions
            .filter {
                $0.persistenceState == .completed
            }
            .filter {
                let startedAt =
                    $0.session.timing.startDate

                return startedAt >= startDate
                    && startedAt < endDate
            }
    }

    func deleteSession(
        id: UUID
    ) async throws {}

    func deleteAllSessions() async throws {}
}
