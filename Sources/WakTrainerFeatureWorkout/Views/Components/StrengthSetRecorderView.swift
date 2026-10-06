import WakTrainerCoreModels
import SwiftUI
import UIKit

struct StrengthSetRecorderView: View {

    @ObservedObject var viewModel: WorkoutSessionViewModel

    @State private var weightText = ""
    @State private var repetitionsText = ""
    @State private var isWarmup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !viewModel.strengthSets.isEmpty {
                completedSets
            }

            if viewModel.isResting {
                restPanel
            } else {
                setInput
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }

    private var header: some View {
        HStack {
            Text("세트 기록")
                .font(.headline)

            Spacer()

            Text(
                "Set \(viewModel.nextStrengthSetNumber)"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var completedSets: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 8) {
                ForEach(viewModel.strengthSets) { set in
                    VStack(spacing: 2) {
                        Text("\(set.setNumber)세트")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(setDescription(set))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 10
                        )
                    )
                }
            }
        }
    }

    private var setInput: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                inputField(
                    title: "중량",
                    text: $weightText,
                    unit: "kg",
                    keyboardType: .decimalPad
                )

                inputField(
                    title: "횟수",
                    text: $repetitionsText,
                    unit: "회",
                    keyboardType: .numberPad
                )
            }

            Toggle(
                "워밍업 세트",
                isOn: $isWarmup
            )
            .font(.subheadline)

            Button {
                completeSet()
            } label: {
                Text("세트 완료")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCompleteSet)
        }
    }

    private var restPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("휴식")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formattedRestTime)
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
            }

            Button {
                viewModel.finishRestAndStartNextSet()
            } label: {
                Text("다음 세트 시작")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        unit: String,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 6) {
            TextField(
                title,
                text: text
            )
            .keyboardType(keyboardType)
            .textFieldStyle(.roundedBorder)

            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var canCompleteSet: Bool {
        guard viewModel.timerState == .running,
              let repetitions = Int(repetitionsText),
              repetitions > 0 else {
            return false
        }

        return parsedWeight >= 0
    }

    private var parsedWeight: Double {
        let normalized = weightText
            .replacingOccurrences(
                of: ",",
                with: "."
            )

        return Double(normalized) ?? 0
    }

    private func completeSet() {
        guard let repetitions =
                Int(repetitionsText) else {
            return
        }

        _ = viewModel.recordStrengthSet(
            weightKilograms: parsedWeight,
            repetitions: repetitions,
            isWarmup: isWarmup
        )
    }

    private var formattedRestTime: String {
        let totalSeconds =
            Int(viewModel.restElapsedTime)

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }

    private func setDescription(
        _ set: WakTrainerCoreModels.StrengthSetRecord
    ) -> String {
        let weight = set.weightKilograms ?? 0
        let repetitions = set.repetitions ?? 0

        return String(
            format: "%.1fkg × %d",
            weight,
            repetitions
        )
    }
}
