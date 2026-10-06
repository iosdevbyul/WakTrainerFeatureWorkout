import Foundation
import Testing
@testable import WakTrainerFeatureWorkout

struct WorkoutMetricsAnalyticsTests {
    @Test
    func emptyMetricsDoNotShowInventedHeartRateOrZones() {
        let result = makeResult(samples: [], age: 35)

        #expect(result.averageHeartRateBPM == nil)
        #expect(result.heartRateZoneDurations.isEmpty)
        #expect(result.averagePaceSecondsPerKilometer == nil)
        #expect(result.averageActiveCaloriesPerHour == 600)
    }

    @Test
    func arithmeticHeartRateAndZoneCoverageFromObservations() {
        let start = Date(timeIntervalSince1970: 1_000)
        let samples = [
            sample(at: start, hr: 100),
            sample(at: start.addingTimeInterval(10), hr: 140),
            sample(at: start.addingTimeInterval(20), hr: 170),
            sample(at: start.addingTimeInterval(80), hr: 180)
        ]
        let result = makeResult(samples: samples, age: 20)

        #expect(result.averageHeartRateBPM == 147.5)
        #expect(result.minimumHeartRateBPM == 100)
        #expect(result.maximumHeartRateBPM == 180)
        #expect(result.estimatedMaximumHeartRateBPM == 200)
        #expect(result.heartRateZoneCoverageSeconds == 20)
        #expect(result.heartRateZoneDurations[1] == 10)
        #expect(result.heartRateZoneDurations[3] == 10)
        #expect(result.heartRateZoneDurations[5] == nil)
    }

    @Test
    func paceAndCadenceAreAvailableOnlyForMovingWorkouts() {
        let base = makeResult(samples: [], age: nil)
        #expect(base.averageCadenceStepsPerMinute == nil)

        let moving = WorkoutFeatureResult(
            workoutID: "run",
            workoutName: "달리기",
            duration: 600,
            distanceMeters: 2000,
            activeCalories: 100,
            stepCount: 1200,
            requiresLocationTracking: true
        )
        #expect(moving.averagePaceSecondsPerKilometer == 300)
        #expect(moving.averageSpeedKilometersPerHour == 12)
        #expect(moving.averageCadenceStepsPerMinute == 120)
    }

    private func makeResult(
        samples: [WorkoutMetricSample],
        age: Int?
    ) -> WorkoutFeatureResult {
        WorkoutFeatureResult(
            workoutID: "squat",
            workoutName: "스쿼트",
            duration: 600,
            distanceMeters: 0,
            activeCalories: 100,
            stepCount: 0,
            ageAtWorkout: age,
            metricSamples: samples
        )
    }

    private func sample(at date: Date, hr: Double) -> WorkoutMetricSample {
        WorkoutMetricSample(
            recordedAt: date,
            heartRateBPM: hr,
            activeCaloriesKcal: nil,
            stepCount: nil,
            distanceMeters: nil
        )
    }
}
