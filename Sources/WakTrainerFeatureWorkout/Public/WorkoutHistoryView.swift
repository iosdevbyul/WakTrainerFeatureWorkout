import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceWorkoutStorage

@MainActor
public struct WorkoutHistoryView: View {

    @StateObject
    private var viewModel:
        WorkoutHistoryViewModel

    @State
    private var automaticReportSession:
        WorkoutSession?

    @State
    private var timeZoneRevision = 0

    @State
    private var hasAppeared = false

    private var historyReloadKey: String {
        "\(selectedDate?.timeIntervalSince1970.description ?? "all")-\(timeZoneRevision)"
    }

    private let selectedDate: Date?
    private let maximumHeartRate: Double?
    private let sessionRepository: (any WorkoutSessionRepository)?

    public init(
        selectedDate: Date? = nil,
        maximumHeartRate: Double? = nil,
        ownerUserID: UUID? = nil
    ) {
        let repository =
            try? SwiftDataWorkoutSessionRepository(ownerUserID: ownerUserID)

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
        self.sessionRepository = sessionRepository
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
        .onAppear {
            if hasAppeared {
                Task { await viewModel.load(selectedDate: selectedDate) }
            } else {
                hasAppeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
            timeZoneRevision += 1
        }
        .task(id: historyReloadKey) {
            automaticReportSession = nil

            await viewModel.load(
                selectedDate: selectedDate
            )

            openSingleWorkoutIfNeeded()
        }
        .navigationDestination(
            isPresented: Binding(
                get: {
                    automaticReportSession != nil
                },
                set: { isPresented in
                    if !isPresented {
                        automaticReportSession = nil
                    }
                }
            )
        ) {
            if let session =
                    automaticReportSession {
                HistoricalWorkoutReportView(
                    session: session,
                    maximumHeartRate:
                        maximumHeartRate,
                    sessionRepository: sessionRepository,
                    onSessionChanged: { _ in
                        Task { await viewModel.load(selectedDate: selectedDate) }
                    }
                )
            }
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
                            maximumHeartRate,
                        sessionRepository: sessionRepository,
                        onSessionChanged: { _ in
                            Task { await viewModel.load(selectedDate: selectedDate) }
                        }
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
                    // Make the entire visible row, including its empty space,
                    // participate in the NavigationLink hit-testing region.
                    .contentShape(Rectangle())
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

    func openSingleWorkoutIfNeeded() {
        guard selectedDate != nil,
              viewModel.sessions.count == 1 else {
            return
        }

        automaticReportSession =
            viewModel.sessions[0].session
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

@MainActor
private struct HistoricalWorkoutReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var restoreModel: WorkoutPauseRestoreViewModel
    @State private var showingRestore = false
    @State private var showingStrengthEditor = false
    private let editStorage: (any WorkoutPauseRestoreStorage)?

    private let maximumHeartRate: Double?
    private let onSessionChanged: (WorkoutSession) -> Void

    init(
        session: WorkoutSession,
        maximumHeartRate: Double?,
        sessionRepository: (any WorkoutSessionRepository)?,
        onSessionChanged: @escaping (WorkoutSession) -> Void
    ) {
        self.onSessionChanged = onSessionChanged
        self.maximumHeartRate = maximumHeartRate
        self.editStorage = sessionRepository as? any WorkoutPauseRestoreStorage
        _restoreModel = StateObject(wrappedValue: WorkoutPauseRestoreViewModel(
            session: session,
            storage: sessionRepository as? any WorkoutPauseRestoreStorage
        ))
    }

    private var reportRevision: String {
        let pauses = restoreModel.session.timing.pauseIntervals.map { "\($0.startDate.timeIntervalSince1970)-\($0.endDate.timeIntervalSince1970)" }.joined(separator: "|")
        let sets = restoreModel.session.exerciseRecords.flatMap(\.strengthSets).map { "\($0.id)-\($0.weightKilograms ?? -1)-\($0.repetitions ?? -1)-\($0.isWarmup)" }.joined(separator: "|")
        return pauses + ":" + sets
    }

    var body: some View {
        VStack(spacing: 0) {
            if restoreModel.canRestore || restoreModel.canUndo || (editStorage != nil && restoreModel.session.exerciseRecords.contains(where: { $0.kind == .strength })) {
                HStack {
                    if editStorage != nil && restoreModel.session.exerciseRecords.contains(where: { $0.kind == .strength }) {
                        Button("Edit Sets") { showingStrengthEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                    if restoreModel.canRestore {
                        Button("Restore Paused Time") {
                            showingRestore = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if restoreModel.canUndo {
                        Button("Undo Restore") {
                            Task { await restoreModel.undo() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            if let error = restoreModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            WorkoutReportView(
                session: restoreModel.session,
                maximumHeartRate: maximumHeartRate
            ) {
                dismiss()
            }
            .id(reportRevision)
        }
        .sheet(isPresented: $showingRestore) {
            WorkoutPauseRestoreSheet(viewModel: restoreModel)
        }
        .sheet(isPresented: $showingStrengthEditor) {
            HistoricalStrengthSetEditor(
                session: restoreModel.session,
                storage: editStorage,
                onSaved: { updated in
                    restoreModel.replaceDisplayedSession(updated)
                }
            )
        }
        .onChange(of: restoreModel.session) { _, updated in
            onSessionChanged(updated)
        }
    }
}
