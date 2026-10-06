import Foundation

/// Completed workout data. Only directly observed metrics are persisted;
/// measurements not supplied by sensors are represented as nil.
public struct WorkoutFeatureResult: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let workoutID: String
    public let workoutName: String
    /// Timer duration, excluding elapsed time while paused.
    public let duration: TimeInterval
    public let distanceMeters: Double
    public let activeCalories: Double
    public let stepCount: Double
    public let startedAt: Date
    public let endedAt: Date
    public let ageAtWorkout: Int?
    public let requiresLocationTracking: Bool
    public let metricSamples: [WorkoutMetricSample]
    public let routePoints: [WorkoutRoutePoint]

    init(
        id: UUID = UUID(),
        workoutID: String,
        workoutName: String,
        duration: TimeInterval,
        distanceMeters: Double,
        activeCalories: Double,
        stepCount: Double,
        startedAt: Date = Date(),
        endedAt: Date = Date(),
        ageAtWorkout: Int? = nil,
        requiresLocationTracking: Bool = false,
        metricSamples: [WorkoutMetricSample] = [],
        routePoints: [WorkoutRoutePoint] = []
    ) {
        self.id = id
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
        self.stepCount = stepCount
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.ageAtWorkout = ageAtWorkout
        self.requiresLocationTracking = requiresLocationTracking
        self.metricSamples = metricSamples
        self.routePoints = routePoints
    }
}

public extension WorkoutFeatureResult {
    var measuredHeartRates: [Double] {
        metricSamples.compactMap {
            guard let bpm = $0.heartRateBPM, bpm.isFinite, bpm > 0 else {
                return nil
            }
            return bpm
        }
    }

    /// Arithmetic mean of app observations; not a time-weighted or clinical average.
    var averageHeartRateBPM: Double? {
        let rates = measuredHeartRates
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    var minimumHeartRateBPM: Double? {
        measuredHeartRates.min()
    }

    var maximumHeartRateBPM: Double? {
        measuredHeartRates.max()
    }

    /// Simple age-based estimate. Not an individually measured max heart rate.
    var estimatedMaximumHeartRateBPM: Double? {
        guard let age = ageAtWorkout, (12...100).contains(age) else {
            return nil
        }
        return 220.0 - Double(age)
    }

    /// Total active energy per elapsed exercise hour, if energy was observed.
    var averageActiveCaloriesPerHour: Double? {
        guard duration > 0, activeCalories > 0 else { return nil }
        return activeCalories / duration * 3_600
    }

    /// Average pace based on workout distance, not instantaneous GPS speed.
    var averagePaceSecondsPerKilometer: Double? {
        guard requiresLocationTracking, distanceMeters > 0, duration > 0 else {
            return nil
        }
        return duration / (distanceMeters / 1_000)
    }

    var averageSpeedKilometersPerHour: Double? {
        guard requiresLocationTracking, distanceMeters > 0, duration > 0 else {
            return nil
        }
        return distanceMeters / duration * 3.6
    }

    var averageCadenceStepsPerMinute: Double? {
        guard requiresLocationTracking, stepCount > 0, duration > 0 else {
            return nil
        }
        return stepCount / (duration / 60)
    }

    /// Time coverage is limited to consecutive observations at most 30 s apart.
    /// Stale heart-rate values are never extrapolated over long gaps.
    var heartRateZoneDurations: [Int: TimeInterval] {
        guard let estimatedMaximumHeartRateBPM else {
            return [:]
        }

        let points = metricSamples
            .compactMap { sample -> (Date, Double)? in
                guard let heartRate = sample.heartRateBPM,
                      heartRate.isFinite, heartRate > 0 else {
                    return nil
                }
                return (sample.recordedAt, heartRate)
            }
            .sorted { $0.0 < $1.0 }

        guard points.count >= 2 else { return [:] }

        var durations: [Int: TimeInterval] = [:]
        for index in 0..<(points.count - 1) {
            let seconds = points[index + 1].0.timeIntervalSince(points[index].0)
            guard seconds > 0, seconds <= 30 else { continue }

            let ratio = points[index].1 / estimatedMaximumHeartRateBPM
            let zone: Int
            switch ratio {
            case ..<0.5: zone = 0
            case ..<0.6: zone = 1
            case ..<0.7: zone = 2
            case ..<0.8: zone = 3
            case ..<0.9: zone = 4
            default: zone = 5
            }
            durations[zone, default: 0] += seconds
        }

        return durations
    }

    var heartRateZoneCoverageSeconds: TimeInterval {
        heartRateZoneDurations.values.reduce(0, +)
    }

    var elevationGainMeters: Double? {
        guard requiresLocationTracking else { return nil }
        let valid = routePoints.compactMap { $0.altitudeMeters }
        guard valid.count >= 2 else { return nil }

        let gain = zip(valid, valid.dropFirst())
            .reduce(0.0) { total, pair in
                let delta = pair.1 - pair.0
                return delta > 3 ? total + delta : total
            }
        return gain
    }
}
