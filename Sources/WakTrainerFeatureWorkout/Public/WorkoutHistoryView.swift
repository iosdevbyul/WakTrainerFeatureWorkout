import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceWorkoutStorage

@MainActor
public struct WorkoutHistoryView: View {

    @StateObject
    private var viewModel:
        WorkoutHistoryViewModel

    private let selectedDate: Date?
    private let maximumHeartRate: Double?

    public init(
        selectedDate: Date? = nil,
        maximumHeartRate: Double? = nil
    ) {
        let repository =
            try? SwiftDataWorkoutSessionRepository()

        self.init(
            selectedDate: selectedDate,
            maximumHeartRate:
                maximumHeartRate,
            sessionRepository: repository
        )
    }

    init(
        selectedDate: Date?,
        maximumHeartRate: Double?,
        sessionRepository:
            (any WorkoutSessionRepository)?
    ) {
        self.selectedDate = selectedDate
        self.maximumHeartRate =
            maximumHeartRate

        _viewModel = StateObject(
            wrappedValue:
                WorkoutHistoryViewModel(
                    sessionRepository:
                        sessionRepository
                )
        )
    }

    public var body: some View {
        Group {
            if selectedDate == nil {
                ScrollView {
                    content
                        .padding()
                }
            } else {
                content
            }
        }
        .task(id: selectedDate) {
            await viewModel.load(
                selectedDate: selectedDate
            )
        }
    }
}

private extension WorkoutHistoryView {

    @ViewBuilder
    var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading Workouts")
                .frame(
                    maxWidth: .infinity,
                    minHeight: 160
                )
        } else if let errorMessage =
                    viewModel.errorMessage {
            ContentUnavailableView(
                "Unable to Load Workouts",
                systemImage:
                    "exclamationmark.triangle",
                description:
                    Text(errorMessage)
            )
        } else if viewModel.sessions.isEmpty {
            ContentUnavailableView(
                "No Workouts",
                systemImage: "figure.run",
                description: Text(
                    emptyDescription
                )
            )
        } else {
            historyList
        }
    }

    var historyList: some View {
        VStack(spacing: 0) {
            ForEach(
                viewModel.sessions,
                id: \.session.id
            ) { storedSession in
                NavigationLink {
                    HistoricalWorkoutReportView(
                        session:
                            storedSession.session,
                        maximumHeartRate:
                            maximumHeartRate
                    )
                } label: {
                    WorkoutHistoryRow(
                        session:
                            storedSession.session
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if storedSession.session.id
                    != viewModel.sessions
                        .last?.session.id {
                    Divider()
                }
            }
        }
        .padding(.horizontal)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }

    var emptyDescription: String {
        selectedDate == nil
            ? "Complete a workout to see its report here."
            : "There are no recorded workouts for this day."
    }
}

private struct WorkoutHistoryRow: View {

    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(session.workout.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(
                    session.timing.startDate
                        .formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text(
                        formatDuration(
                            session.timing
                                .activeDuration
                        )
                    )

                    if let calories =
                            session.health
                                .summary
                                .activeCalories {
                        Text(
                            calories.formatted(
                                .number
                                    .precision(
                                        .fractionLength(0)
                                    )
                            ) + " kcal"
                        )
                    }

                    if let distance =
                            session.health
                                .summary
                                .distanceMeters,
                       distance > 0 {
                        Text(
                            (distance / 1_000)
                                .formatted(
                                    .number
                                        .precision(
                                            .fractionLength(2)
                                        )
                                )
                            + " km"
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
    }

    private func formatDuration(
        _ duration: TimeInterval
    ) -> String {
        let totalMinutes =
            max(0, Int(duration)) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }

        return "\(minutes) min"
    }
}

private struct HistoricalWorkoutReportView: View {

    @Environment(\.dismiss)
    private var dismiss

    let session: WorkoutSession
    let maximumHeartRate: Double?

    var body: some View {
        WorkoutReportView(
            session: session,
            maximumHeartRate:
                maximumHeartRate
        ) {
            dismiss()
        }
    }
}
