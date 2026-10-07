import Combine
import Foundation
import WakTrainerDomainWorkout

@MainActor
final class WorkoutHistoryViewModel: ObservableObject {

    @Published private(set) var sessions:
        [StoredWorkoutSession] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let sessionRepository:
        (any WorkoutSessionRepository)?

    init(
        sessionRepository:
            (any WorkoutSessionRepository)?
    ) {
        self.sessionRepository = sessionRepository
    }

    func load(
        selectedDate: Date?,
        calendar: Calendar = .current
    ) async {
        guard let sessionRepository else {
            sessions = []
            errorMessage =
                "Workout history storage is unavailable."
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            if let selectedDate {
                let startDate =
                    calendar.startOfDay(
                        for: selectedDate
                    )

                guard let endDate =
                        calendar.date(
                            byAdding: .day,
                            value: 1,
                            to: startDate
                        ) else {
                    throw WorkoutHistoryError
                        .invalidDateInterval
                }

                sessions =
                    try await sessionRepository
                        .fetchCompletedSessions(
                            from: startDate,
                            to: endDate
                        )
            } else {
                sessions =
                    try await sessionRepository
                        .fetchSessions()
                        .filter {
                            $0.persistenceState
                                == .completed
                        }
                        .sorted {
                            $0.session.timing
                                .startDate
                                >
                            $1.session.timing
                                .startDate
                        }
            }
        } catch {
            sessions = []
            errorMessage =
                error.localizedDescription
        }
    }
}

private enum WorkoutHistoryError:
    LocalizedError {

    case invalidDateInterval

    var errorDescription: String? {
        switch self {
        case .invalidDateInterval:
            "The selected date could not be loaded."
        }
    }
}
