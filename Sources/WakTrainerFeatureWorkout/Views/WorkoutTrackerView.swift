import SwiftUI

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
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(
                title: "Heart Rate",
                value: "\(Int(viewModel.heartRate))",
                unit: "BPM",
                iconName: "heart.fill",
                iconColor: .red
            )

            MetricCard(
                title: "Calories",
                value: "\(Int(viewModel.activeCalories))",
                unit: "kcal",
                iconName: "flame.fill",
                iconColor: .orange
            )

            MetricCard(
                title: "Steps",
                value: "\(Int(viewModel.stepCount))",
                unit: "steps",
                iconName: "shoeprints.fill",
                iconColor: .blue
            )

            MetricCard(
                title: "Distance",
                value: String(format: "%.2f", viewModel.distanceKilometers),
                unit: "km",
                iconName: "figure.walk",
                iconColor: .green
            )
        }
    }
}
