import SwiftUI
import WakTrainerCoreModels

public extension View {

    func wakTrainerWorkoutLauncher(
        maximumHeartRate: Double? = nil,
        bottomPadding: CGFloat = 12,
        onFinished: @escaping (WorkoutSession) -> Void
    ) -> some View {
        overlay(
            alignment: .bottom
        ) {
            WorkoutLauncherView(
                maximumHeartRate: maximumHeartRate,
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
