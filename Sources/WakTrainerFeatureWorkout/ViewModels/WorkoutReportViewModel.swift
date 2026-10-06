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

    var strengthSets: [StrengthSetRecord] {
        session.exerciseRecords
            .flatMap(\.strengthSets)
            .filter(\.isCompleted)
    }
}
