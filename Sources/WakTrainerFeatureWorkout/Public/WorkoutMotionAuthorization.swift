import Foundation
import TrisMotionKit

/// App-level entry point to prepare Motion & Fitness access alongside
/// HealthKit authorization, before the user starts a workout.
public enum WorkoutMotionAuthorization {
    public static func prepareIfAvailable() async {
        // Motion data is optional. Denial or unavailable hardware must not
        // prevent HealthKit authorization or workout navigation.
        try? await PedometerService().prepareAuthorization()
    }
}
