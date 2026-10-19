import Foundation
import WakTrainerCoreModels

/// Synthetic measurements for simulator development only.
/// This source must never write into HealthKit.
@MainActor
struct DebugWorkoutSimulator {
    private(set) var samples: [WorkoutHealthMetricSample] = []
    private(set) var route: [WorkoutRoutePoint] = []
    private(set) var heartRate: Double = 90
    private(set) var calories: Double = 0
    private(set) var steps: Double = 0
    private(set) var distance: Double = 0
    private var seconds: Double = 0

    mutating func advance(at date: Date, category: String, workoutID: String) {
        seconds += 1
        let strength = category == "strength"
        let walking = workoutID.contains("walking")
        let cycling = workoutID.contains("cycling")
        let speed = strength ? 0 : cycling ? 5.6 : walking ? 1.4 : 2.8
        let targetHR = strength ? 125.0 : walking ? 112.0 : cycling ? 140.0 : 150.0
        let variation = sin(seconds / 8) * 6 + sin(seconds / 17) * 3
        heartRate = min(185, max(65, 85 + (targetHR - 85) * min(seconds / 45, 1) + variation))
        calories += strength ? 0.11 : walking ? 0.07 : cycling ? 0.14 : 0.17
        steps += strength || cycling ? 0 : walking ? 1.7 : 2.8
        distance += speed

        func add(_ metric: WorkoutHealthMetric, _ value: Double, _ unit: String) {
            samples.append(WorkoutHealthMetricSample(
                metric: metric, startDate: date, endDate: date,
                value: value, unit: unit,
                sourceName: "WakTrainer Debug Simulator",
                sourceBundleIdentifier: "com.tris.WakTrainer.debug-simulation"
            ))
        }
        add(.heartRate, heartRate, "count/min")
        add(.activeEnergyBurned, calories, "kcal")
        if !strength && !cycling { add(.stepCount, steps, "count") }
        if !strength {
            add(cycling ? .distanceCycling : .distanceWalkingRunning, distance, "m")
        }
        if speed > 0 {
            // A smooth synthetic eastward path, not real device location.
            let eastMeters = distance
            let latitude = 37.5665 + sin(seconds / 120) * 0.00015
            let longitude = 126.9780 + eastMeters / 88_700
            route.append(WorkoutRoutePoint(
                timestamp: date, latitude: latitude, longitude: longitude,
                speedMetersPerSecond: speed, horizontalAccuracy: 5
            ))
        }
    }

    var health: WorkoutHealthData {
        let hrs = samples.filter { $0.metric == .heartRate }.map(\.value)
        return WorkoutHealthData(
            summary: WorkoutHealthSummary(
                averageHeartRate: hrs.isEmpty ? nil : hrs.reduce(0,+) / Double(hrs.count),
                minimumHeartRate: hrs.min(),
                maximumHeartRate: hrs.max(),
                activeCalories: calories,
                stepCount: steps,
                distanceMeters: distance
            ),
            samples: samples
        )
    }
}
