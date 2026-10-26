import SwiftUI
import WakTrainerCoreModels

struct WorkoutTrackerView: View {
    @ObservedObject private var viewModel: WorkoutSessionViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(viewModel: WorkoutSessionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = viewModel.healthDataCollectionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if viewModel.healthSampleEndDates.isEmpty {
                Label("Waiting for HealthKit samples. Heart rate may require a paired device or another active source.", systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(
                title: "Heart Rate",
                value: viewModel.healthSampleEndDates[.heartRate] == nil ? "—" : "\(Int(viewModel.heartRate))",
                unit: "BPM",
                iconName: "heart.fill",
                iconColor: .red
            )

            MetricCard(
                title: "Calories",
                value: viewModel.healthSampleEndDates[.activeEnergyBurned] == nil ? "—" : "\(Int(viewModel.activeCalories))",
                unit: "kcal",
                iconName: "flame.fill",
                iconColor: .orange
            )

            MetricCard(
                title: "Steps",
                value: viewModel.healthSampleEndDates[.stepCount] == nil ? "—" : "\(Int(viewModel.stepCount))",
                unit: "steps",
                iconName: "shoeprints.fill",
                iconColor: .blue
            )

            MetricCard(
                title: "Distance",
                value: viewModel.healthSampleEndDates[.distanceWalkingRunning] == nil && viewModel.healthSampleEndDates[.distanceCycling] == nil ? "—" : String(format: "%.2f", viewModel.distanceKilometers),
                unit: "km",
                iconName: "figure.walk",
                iconColor: .green
            )
            }
        }
    }
}
