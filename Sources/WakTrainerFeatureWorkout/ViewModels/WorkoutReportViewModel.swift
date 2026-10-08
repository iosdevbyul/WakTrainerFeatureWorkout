import Combine
import Foundation
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@MainActor
final class WorkoutReportViewModel: ObservableObject {

    let session: WorkoutSession
    let report: WorkoutReport

    init(
        session: WorkoutSession,
        maximumHeartRate: Double? = nil
    ) {
        self.session = session
        self.report = WorkoutReportBuilder(
            maximumHeartRate: maximumHeartRate
        )
        .makeReport(from: session)
    }

    var heartRateSamples: [WorkoutHealthMetricSample] {
        session.health.samples(
            for: .heartRate
        )
    }

    var strengthExerciseRecords: [WorkoutExerciseRecord] {
        session.exerciseRecords.filter {
            $0.kind == .strength
        }
    }

    var strengthSets: [StrengthSetRecord] {
        strengthExerciseRecords
            .flatMap(\.strengthSets)
            .filter(\.isCompleted)
    }
}
