import SwiftUI
import WakTrainerCoreModels

public extension View {

    func wakTrainerWorkoutLauncher(
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        strengthLocationPolicy: StrengthWorkoutLocationPolicy = .singleLocation,
        bottomPadding: CGFloat = 12,
        onFinished: @escaping (WorkoutSession) -> Void
    ) -> some View {
        overlay(
            alignment: .bottom
        ) {
            WorkoutLauncherView(
                maximumHeartRate: maximumHeartRate,
                weightUnit: weightUnit,
                strengthLocationPolicy: strengthLocationPolicy,
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
