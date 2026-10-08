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

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            header

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
                }
            }
        }
    }

    private var setInput:
        some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if requiresWeightInput {
                    inputField(
                        title: "Weight",
                        text:
                            $weightText,
                        unit: weightUnit.rawValue,
                        keyboardType:
                            .decimalPad
                    )
                }

                inputField(
                    title: "Reps",
                    text:
                        $repetitionsText,
                    unit: "reps",
                    keyboardType:
                        .numberPad
                )
            }

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
            .buttonStyle(
                .borderedProminent
            )
            .disabled(
                !canCompleteSet
            )
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
        keyboardType:
            UIKeyboardType
    ) -> some View {
        HStack(spacing: 6) {
            TextField(
                title,
                text: text
            )
            .keyboardType(
                keyboardType
            )
            .textFieldStyle(
                .roundedBorder
            )

            Text(unit)
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
        }
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
                        isWarmup
                )

        guard didRecord else {
            return
        }

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
