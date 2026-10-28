import SwiftUI
import WakTrainerCoreModels

struct WorkoutTrackerView: View {
    @ObservedObject private var viewModel: WorkoutSessionViewModel

    var compact: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(viewModel: WorkoutSessionViewModel, compact: Bool = false) {
        self.viewModel = viewModel
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if let error = viewModel.healthDataCollectionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if viewModel.healthSampleEndDates.isEmpty {
                Label("Waiting for HealthKit samples. Heart rate may require a paired device or another active source.", systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: compact ? 8 : 12) {
            MetricCard(
                title: "Heart Rate",
                value: viewModel.healthSampleEndDates[.heartRate] == nil ? "—" : "\(Int(viewModel.heartRate))",
                unit: "BPM",
                iconName: "heart.fill",
                iconColor: .red,
                compact: compact
            )

            MetricCard(
                title: "Calories",
                value: viewModel.healthSampleEndDates[.activeEnergyBurned] == nil ? "—" : "\(Int(viewModel.activeCalories))",
                unit: "kcal",
                iconName: "flame.fill",
                iconColor: .orange,
                compact: compact
            )

            if viewModel.workout.category == .strength {
                MetricCard(
                    title: "Completed Sets",
                    value: "\(completedSetCount)",
                    unit: "sets",
                    iconName: "checkmark.circle.fill",
                    iconColor: .green,
                    compact: compact
                )
                MetricCard(
                    title: "Total Volume",
                    value: totalVolume.formatted(.number.precision(.fractionLength(0...1))),
                    unit: "kg",
                    iconName: "dumbbell.fill",
                    iconColor: .green,
                    compact: compact
                )
            } else {
            MetricCard(
                title: "Steps",
                value: viewModel.healthSampleEndDates[.stepCount] == nil ? "—" : "\(Int(viewModel.stepCount))",
                unit: "steps",
                iconName: "shoeprints.fill",
                iconColor: .blue,
                compact: compact
            )

            MetricCard(
                title: "Distance",
                value: viewModel.healthSampleEndDates[.distanceWalkingRunning] == nil && viewModel.healthSampleEndDates[.distanceCycling] == nil ? "—" : String(format: "%.2f", viewModel.distanceKilometers),
                unit: "km",
                iconName: "figure.walk",
                iconColor: .green,
                compact: compact
            )
            }
            }
        }
    }

    private var completedSets: [StrengthSetRecord] {
        viewModel.completedStrengthExerciseRecords.flatMap(\.strengthSets)
            + viewModel.strengthSets
    }

    private var completedSetCount: Int {
        completedSets.filter(\.isCompleted).count
    }

    private var totalVolume: Double {
        completedSets.filter(\.isCompleted).reduce(0) { result, set in
            result + (set.weightKilograms ?? 0) * Double(set.repetitions)
        }
    }
}
