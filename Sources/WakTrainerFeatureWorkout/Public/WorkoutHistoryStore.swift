import Combine
import Foundation
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceWorkoutStorage

@MainActor
public final class WorkoutHistoryStore: ObservableObject {

    @Published
    public private(set) var sessions:
        [StoredWorkoutSession] = []

    @Published
    public private(set) var isLoading = false

    @Published
    public private(set) var errorMessage: String?

    private let repositoryProvider:
        () throws -> any WorkoutSessionRepository

    public convenience init() {
        self.init(
            repositoryProvider: {
                try SwiftDataWorkoutSessionRepository()
            }
        )
    }

    init(
        repositoryProvider:
            @escaping () throws ->
                any WorkoutSessionRepository
    ) {
        self.repositoryProvider =
            repositoryProvider
    }

    public var latestSession: WorkoutSession? {
        sessions.first?.session
    }

    public func reload() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let repository =
                try repositoryProvider()

            sessions =
                try await repository
                    .fetchSessions()
                    .filter {
                        $0.persistenceState
                            == .completed
                    }
                    .sorted {
                        $0.session.timing.startDate
                            >
                        $1.session.timing.startDate
                    }
        } catch {
            sessions = []
            errorMessage =
                error.localizedDescription
        }
    }

    public func highlightedDates(
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(
            sessions.map {
                calendar.startOfDay(
                    for:
                        $0.session.timing
                            .startDate
                )
            }
        )
    }
}
