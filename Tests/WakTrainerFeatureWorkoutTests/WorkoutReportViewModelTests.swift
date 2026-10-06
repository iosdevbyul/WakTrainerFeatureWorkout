import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("WorkoutReportViewModel")
struct WorkoutReportViewModelTests {

    @Test("리포트 뷰 모델은 WorkoutSession에서 report를 생성한다")
    func buildsReportFromSession() {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "bench_press",
                name: "벤치프레스",
                category: "strength",
                type: .staticWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(1_200),
                elapsedDuration: 1_200,
                activeDuration: 1_000,
                pausedDuration: 200
            ),
            exerciseRecords: [
                WorkoutExerciseRecord(
                    exerciseID: "bench_press",
                    name: "벤치프레스",
                    kind: .strength,
                    startDate: start,
                    endDate: start.addingTimeInterval(1_200),
                    strengthSets: [
                        StrengthSetRecord(
                            setNumber: 1,
                            weightKilograms: 80,
                            repetitions: 8,
                            restDuration: 90,
                            isCompleted: true
                        )
                    ]
                )
            ],
            health: WorkoutHealthData(
                summary: WorkoutHealthSummary(
                    averageHeartRate: 130,
                    maximumHeartRate: 160,
                    activeCalories: 180
                )
            )
        )

        let viewModel = WorkoutReportViewModel(
            session: session
        )

        #expect(viewModel.report.sessionID == session.id)
        #expect(viewModel.report.workout.name == "벤치프레스")
        #expect(viewModel.report.summary.activeDuration == 1_000)
        #expect(viewModel.report.summary.activeCalories == 180)
        #expect(viewModel.report.strength?.workingSets == 1)
        #expect(viewModel.report.strength?.totalVolumeKilograms == 640)
    }

    @Test("maximumHeartRate를 주입하면 heart zone이 생성된다")
    func maximumHeartRateEnablesZones() {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let samples = [100.0, 130, 150, 170, 190].enumerated().map {
            index,
            value in

            WorkoutHealthMetricSample(
                metric: .heartRate,
                startDate:
                    start.addingTimeInterval(
                        Double(index * 5)
                    ),
                endDate:
                    start.addingTimeInterval(
                        Double(index * 5 + 1)
                    ),
                value: value,
                unit: "bpm"
            )
        }

        let session = WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "running",
                name: "달리기",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(600),
                elapsedDuration: 600,
                activeDuration: 600,
                pausedDuration: 0
            ),
            health: WorkoutHealthData(
                samples: samples
            )
        )

        let viewModel = WorkoutReportViewModel(
            session: session,
            maximumHeartRate: 200
        )

        #expect(viewModel.heartRateSamples.count == 5)
        #expect(viewModel.report.heart.zones.count == 5)
    }
}
