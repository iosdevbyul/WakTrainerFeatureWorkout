import WakTrainerCoreModels
import SwiftUI
import UIKit

struct StrengthSetRecorderView: View {

    @ObservedObject var viewModel:
        WorkoutSessionViewModel
    let weightUnit: WorkoutWeightUnit

    @State private var weightText = ""
    @State private var repetitionsText = ""
    @State private var isWarmup = false
    @State private var editingSet: StrengthSetRecord?
    @AppStorage("WakTrainer.strength.trackRest") private var trackRest = false
    @FocusState private var focusedInput: SetInput?

    private enum SetInput: Hashable {
        case weight
        case reps
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            header
                .contentShape(Rectangle())
                .onTapGesture { focusedInput = nil }

            if !viewModel.strengthSets
                .isEmpty {
                completedSets
            }

            if viewModel.isResting {
                restPanel
            } else {
                setInput
            }
        }
        .padding(16)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { focusedInput = nil }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
        .onChange(of: viewModel.strengthSets.count) {
            fillPreviousSet()
        }
        .onAppear { fillPreviousSet() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedInput = nil }
            }
        }
        .sheet(item: $editingSet) { set in
            StrengthSetEditSheet(set: set, weightUnit: weightUnit,
                                 requiresWeight: requiresWeightInput) { weight, reps, warmup in
                viewModel.updateStrengthSet(id: set.id, weightKilograms: weight,
                                            repetitions: reps, isWarmup: warmup)
            }
        }
        .onChange(
            of:
                viewModel
                    .activeStrengthExercise?
                    .id
        ) {
            weightText = ""
            repetitionsText = ""
            isWarmup = false
        }
    }

    private var header:
        some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    viewModel
                        .activeStrengthExercise?
                        .name
                    ?? "Exercise"
                )
                .font(.headline)

                if let equipment =
                        viewModel
                            .activeStrengthEquipment {
                    Text(
                        equipment
                            .displayName
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Text(
                "Set \(viewModel.nextStrengthSetNumber)"
            )
            .font(.subheadline)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var completedSets:
        some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 8) {
                ForEach(
                    viewModel
                        .strengthSets
                ) { set in
                    VStack(spacing: 2) {
                        Text(
                            "Set \(set.setNumber)"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            setDescription(
                                set
                            )
                        )
                        .font(
                            .subheadline
                        )
                        .fontWeight(
                            .semibold
                        )
                    }
                    .padding(
                        .horizontal,
                        10
                    )
                    .padding(
                        .vertical,
                        8
                    )
                    .background(
                        .thinMaterial
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 10
                        )
                    )
                    .onTapGesture { editingSet = set }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var setInput:
        some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if requiresWeightInput {
                    inputField(
                        title: "Weight",
                        text:
                            $weightText,
                        unit: weightUnit.rawValue,
                        keyboardType:
                            .decimalPad,
                        focus: .weight
                    )
                }

                inputField(
                    title: "Reps",
                    text:
                        $repetitionsText,
                    unit: "reps",
                    keyboardType:
                        .numberPad,
                    focus: .reps
                )
            }

            Toggle("Track Rest Between Sets", isOn: $trackRest)
                .font(.subheadline)

            Toggle(
                "Warm-up Set",
                isOn: $isWarmup
            )
            .font(.subheadline)

            Button {
                completeSet()
            } label: {
                Text("Complete Set")
                    .font(.headline)
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        10
                    )
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .foregroundStyle(.black)
            .opacity(canCompleteSet ? 1 : 0.55)
            .disabled(!canCompleteSet)
        }
    }

    private var restPanel:
        some View {
        VStack(spacing: 10) {
            HStack {
                Text("Rest")
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )

                Spacer()

                Text(
                    formattedRestTime
                )
                .font(
                    .title3
                        .monospacedDigit()
                )
                .fontWeight(
                    .semibold
                )
            }

            Button {
                viewModel
                    .finishRestAndStartNextSet()
            } label: {
                Text(
                    "Start Next Set"
                )
                .font(.headline)
                .frame(
                    maxWidth:
                        .infinity
                )
                .padding(
                    .vertical,
                    10
                )
            }
            .buttonStyle(
                .borderedProminent
            )
        }
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        unit: String,
        keyboardType: UIKeyboardType,
        focus: SetInput
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .keyboardType(keyboardType)
                    .focused($focusedInput, equals: focus)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.8)
                Text(unit)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 60)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }

    private var requiresWeightInput:
        Bool {
        viewModel
            .activeStrengthEquipment?
            .requiresWeightInput
        ?? false
    }

    private var canCompleteSet:
        Bool {
        guard viewModel.timerState
                == .running,
              let repetitions =
                Int(
                    repetitionsText
                ),
              repetitions > 0 else {
            return false
        }

        if requiresWeightInput {
            guard let weight =
                    parsedWeight,
                  weight > 0 else {
                return false
            }
        }

        return true
    }

    private var parsedWeight:
        Double? {
        let normalized =
            weightText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        return Double(
            normalized
        )
    }

    private func completeSet() {
        guard let repetitions =
                Int(
                    repetitionsText
                ) else {
            return
        }

        let didRecord =
            viewModel
                .recordStrengthSet(
                    weightKilograms:
                        requiresWeightInput
                        ? parsedWeight.map { weightUnit.toKilograms($0) }
                        : nil,
                    repetitions:
                        repetitions,
                    isWarmup:
                        isWarmup,
                    startRest: trackRest
                )

        guard didRecord else {
            return
        }

        focusedInput = nil
        fillPreviousSet()
    }

    private func fillPreviousSet() {
        guard let previous = viewModel.strengthSets.last else {
            weightText = ""
            repetitionsText = ""
            isWarmup = false
            return
        }
        if let kilograms = previous.weightKilograms {
            weightText = String(format: "%.1f", weightUnit.fromKilograms(kilograms))
        } else {
            weightText = ""
        }
        repetitionsText = previous.repetitions.map(String.init) ?? ""
        isWarmup = previous.isWarmup
    }

    private var formattedRestTime:
        String {
        let totalSeconds =
            Int(
                viewModel
                    .restElapsedTime
            )

        let minutes =
            totalSeconds / 60
        let seconds =
            totalSeconds % 60

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }

    private func setDescription(
        _ set:
            WakTrainerCoreModels
                .StrengthSetRecord
    ) -> String {
        let repetitions =
            set.repetitions ?? 0

        guard let weight =
                set.weightKilograms else {
            return "\(repetitions) reps"
        }

        return String(
            format:
                "%.1f%@ × %d",
            weightUnit.fromKilograms(weight),
            weightUnit.rawValue,
            repetitions
        )
    }
}

private struct StrengthSetEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let set: StrengthSetRecord
    let weightUnit: WorkoutWeightUnit
    let requiresWeight: Bool
    let onSave: (Double?, Int, Bool) -> Bool

    @State private var weight: String
    @State private var reps: String
    @State private var warmup: Bool

    init(set: StrengthSetRecord, weightUnit: WorkoutWeightUnit,
         requiresWeight: Bool, onSave: @escaping (Double?, Int, Bool) -> Bool) {
        self.set = set
        self.weightUnit = weightUnit
        self.requiresWeight = requiresWeight
        self.onSave = onSave
        _weight = State(initialValue: set.weightKilograms.map {
            String(format: "%.1f", weightUnit.fromKilograms($0))
        } ?? "")
        _reps = State(initialValue: set.repetitions.map(String.init) ?? "")
        _warmup = State(initialValue: set.isWarmup)
    }

    var body: some View {
        NavigationStack {
            Form {
                if requiresWeight {
                    TextField("Weight (\(weightUnit.rawValue))", text: $weight)
                        .keyboardType(.decimalPad)
                }
                TextField("Repetitions", text: $reps).keyboardType(.numberPad)
                Toggle("Warm-up Set", isOn: $warmup)
            }
            .navigationTitle("Edit Set \(set.setNumber)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let count = Int(reps),
                           onSave(parsedWeight, count, warmup) {
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var parsedWeight: Double? {
        guard let value = Double(weight.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        return weightUnit.toKilograms(value)
    }

    private var isValid: Bool {
        guard let count = Int(reps), count > 0 else { return false }
        guard requiresWeight else { return true }
        guard let value = parsedWeight else { return false }
        return value > 0 && value.isFinite
    }
}
