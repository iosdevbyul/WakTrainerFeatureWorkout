import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@MainActor
struct HistoricalStrengthSetEditor: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let storage: (any WorkoutPauseRestoreStorage)?
    let onSaved: (WorkoutSession) -> Void

    @State private var editedRecords: [WorkoutExerciseRecord]
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        session: WorkoutSession,
        storage: (any WorkoutPauseRestoreStorage)?,
        onSaved: @escaping (WorkoutSession) -> Void
    ) {
        self.session = session
        self.storage = storage
        self.onSaved = onSaved
        _editedRecords = State(initialValue: session.exerciseRecords)
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(editedRecords.indices, id: \.self) { recordIndex in
                    if editedRecords[recordIndex].kind == .strength {
                        Section(editedRecords[recordIndex].name) {
                            ForEach(editedRecords[recordIndex].strengthSets.indices, id: \.self) { setIndex in
                                if editedRecords[recordIndex].strengthSets[setIndex].isCompleted {
                                    NavigationLink {
                                        HistoricalStrengthSetForm(
                                            set: $editedRecords[recordIndex].strengthSets[setIndex]
                                        )
                                    } label: {
                                        let set = editedRecords[recordIndex].strengthSets[setIndex]
                                        HStack {
                                            Text("Set \(set.setNumber)")
                                            if set.isWarmup { Text("Warm-up").foregroundStyle(.secondary) }
                                            Spacer()
                                            Text("\(set.weightKilograms.map { String(format: "%.1f kg", $0) } ?? "Bodyweight") · \(set.repetitions ?? 0) reps")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Workout Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || editedRecords == session.exerciseRecords || storage == nil)
                }
            }
        }
    }

    private func save() async {
        guard let storage, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        var updated = session
        updated.exerciseRecords = editedRecords
        do {
            let replaced = try await storage.compareAndReplaceCompleted(expected: session, replacement: updated)
            guard replaced else {
                errorMessage = "Workout changed since editing began. Close and reopen to load the latest record."
                return
            }
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct HistoricalStrengthSetForm: View {
    @Binding var set: StrengthSetRecord
    @State private var weightText = ""
    @State private var repsText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case weight, reps }

    var body: some View {
        Form {
            Section("Set \(set.setNumber)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight (kg)").font(.headline)
                    TextField("Bodyweight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .focused($focusedField, equals: .weight)
                }
                .padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repetitions").font(.headline)
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                        .font(.title2.weight(.semibold))
                        .focused($focusedField, equals: .reps)
                }
                .padding(.vertical, 8)
                Toggle("Warm-up Set", isOn: $set.isWarmup)
            }
            Section {
                Text("Only weight, repetitions and warm-up status are editable. Recorded timestamps, rest duration and HealthKit data are preserved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Set")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    let trimmed = weightText.trimmingCharacters(in: .whitespaces)
                    set.weightKilograms = trimmed.isEmpty ? nil : Double(trimmed)
                    set.repetitions = Int(repsText)
                    focusedField = nil
                    dismiss()
                }
                .disabled(!validInput)
            }
        }
        .onAppear {
            weightText = set.weightKilograms.map { String($0) } ?? ""
            repsText = set.repetitions.map { String($0) } ?? ""
        }
    }

    private var validInput: Bool {
        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        let validWeight = trimmed.isEmpty || (Double(trimmed).map { $0.isFinite && $0 >= 0 } ?? false)
        let validReps = Int(repsText).map { $0 > 0 } ?? false
        return validWeight && validReps
    }
}
