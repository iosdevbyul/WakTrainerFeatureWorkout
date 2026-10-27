import SwiftUI
import WakTrainerCoreModels

public extension View {

    func wakTrainerWorkoutLauncher(
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        strengthLocationPolicy: StrengthWorkoutLocationPolicy = .singleLocation,
        bottomPadding: CGFloat = 12,
        ownerUserID: UUID? = nil,
        resumeRequestID: UUID? = nil,
        onFinished: @escaping (WorkoutSession) -> Void,
        onWorkoutUpdate: ((WorkoutLiveSnapshot) -> Void)? = nil
    ) -> some View {
        overlay(
            alignment: .bottom
        ) {
            WorkoutLauncherView(
                maximumHeartRate: maximumHeartRate,
                weightUnit: weightUnit,
                strengthLocationPolicy: strengthLocationPolicy,
                ownerUserID: ownerUserID,
                resumeRequestID: resumeRequestID,
                onFinished: onFinished,
                onWorkoutUpdate: onWorkoutUpdate
            )
            .padding(.horizontal, 16)
            .padding(
                .bottom,
                bottomPadding
            )
        }
    }
}
