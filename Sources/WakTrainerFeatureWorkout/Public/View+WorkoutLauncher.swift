import SwiftUI
import WakTrainerCoreModels

public extension View {

    func wakTrainerWorkoutLauncher(
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        bottomPadding: CGFloat = 12,
        onFinished: @escaping (WorkoutSession) -> Void
    ) -> some View {
        overlay(
            alignment: .bottom
        ) {
            WorkoutLauncherView(
                maximumHeartRate: maximumHeartRate,
                weightUnit: weightUnit,
                onFinished: onFinished
            )
            .padding(.horizontal, 16)
            .padding(
                .bottom,
                bottomPadding
            )
        }
    }
}
