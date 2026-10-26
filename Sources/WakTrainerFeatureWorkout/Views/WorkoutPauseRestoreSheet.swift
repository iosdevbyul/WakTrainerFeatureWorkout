import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout

/// Select a subrange of one recorded pause. Dates are absolute acquisition
/// instants; changing device time zone does not change the selected interval.
@MainActor
struct WorkoutPauseRestoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkoutPauseRestoreViewModel

    @State private var selectedPause = 0
    @State private var restoreStart = Date()
    @State private var restoreEnd = Date()

    private var pauses: [WorkoutPauseInterval] {
        viewModel.session.timing.pauseIntervals
            .filter { $0.endDate > $0.startDate }
            .sorted { $0.startDate < $1.startDate }
    }

    private var interval: WorkoutPauseInterval? {
        guard pauses.indices.contains(selectedPause) else { return nil }
        return pauses[selectedPause]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recorded Pauses") {
                    if pauses.isEmpty {
                        ContentUnavailableView(
                            "No Pauses to Restore",
                            systemImage: "pause.circle",
                            description: Text("This workout has no remaining recorded pause intervals.")
                        )
                    } else {
                        Picker("Pause Interval", selection: $selectedPause) {
                            ForEach(pauses.indices, id: \.self) { index in
                                Text("\(pauses[index].startDate.formatted(date: .omitted, time: .shortened)) – \(pauses[index].endDate.formatted(date: .omitted, time: .shortened))")
                                    .tag(index)
                            }
                        }
                    }
                }

                if let interval {
                    Section("Restore Range") {
                        DatePicker(
                            "From",
                            selection: $restoreStart,
                            in: interval.startDate...interval.endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        DatePicker(
                            "To",
                            selection: $restoreEnd,
                            in: interval.startDate...interval.endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Text("Restore only the selected time. The remaining pause stays excluded from your workout.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Restore Selected Time") {
                            Task {
                                await viewModel.restore(from: restoreStart, to: restoreEnd)
                                if viewModel.errorMessage == nil { dismiss() }
                            }
                        }
                        .disabled(
                            viewModel.isSaving ||
                            restoreEnd <= restoreStart ||
                            restoreStart < interval.startDate ||
                            restoreEnd > interval.endDate
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Restore Paused Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { selectInterval() }
            .onChange(of: selectedPause) { _, _ in selectInterval() }
            .disabled(viewModel.isSaving)
        }
    }

    private func selectInterval() {
        guard let interval else { return }
        restoreStart = interval.startDate
        restoreEnd = interval.endDate
    }
}
