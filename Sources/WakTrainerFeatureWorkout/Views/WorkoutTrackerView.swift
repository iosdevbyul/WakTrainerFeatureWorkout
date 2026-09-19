//
//  WorkoutTrackerView.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-08-25.
//

import SwiftUI

public struct WorkoutTrackerView: View {
    @ObservedObject private var viewModel: WorkoutSessionViewModel

    public init(viewModel: WorkoutSessionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            MetricCard(
                title: "심박수",
                value: "\(Int(viewModel.heartRate))",
                unit: "BPM",
                iconName: "heart.fill",
                iconColor: .red
            )

            MetricCard(
                title: "소모 칼로리",
                value: "\(Int(viewModel.activeCalories))",
                unit: "kcal",
                iconName: "flame.fill",
                iconColor: .orange
            )

            MetricCard(
                title: "걸음 수",
                value: "\(Int(viewModel.stepCount))",
                unit: "걸음",
                iconName: "shoeprints.fill",
                iconColor: .blue
            )

            MetricCard(
                title: "이동 거리",
                value: String(
                    format: "%.2f",
                    viewModel.distanceKilometers
                ),
                unit: "km",
                iconName: "figure.walk",
                iconColor: .green
            )
        }
    }
}
