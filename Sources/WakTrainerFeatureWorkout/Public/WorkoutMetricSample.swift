import Foundation

/// Latest values observed by the app during a workout.
///
/// `recordedAt` is the app observation time, not necessarily the original
/// HealthKit sensor sample time. A nil measurement means unavailable.
public struct WorkoutMetricSample: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let recordedAt: Date
    public let heartRateBPM: Double?
    public let activeCaloriesKcal: Double?
    public let stepCount: Double?
    public let distanceMeters: Double?

    public init(
        id: UUID = UUID(),
        recordedAt: Date,
        heartRateBPM: Double?,
        activeCaloriesKcal: Double?,
        stepCount: Double?,
        distanceMeters: Double?
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.heartRateBPM = heartRateBPM
        self.activeCaloriesKcal = activeCaloriesKcal
        self.stepCount = stepCount
        self.distanceMeters = distanceMeters
    }
}

/// A GPS fix captured during a movement-based workout, when accuracy is usable.
public struct WorkoutRoutePoint: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let recordedAt: Date
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracyMeters: Double
    public let altitudeMeters: Double?
    public let speedMetersPerSecond: Double?

    public init(
        id: UUID = UUID(),
        recordedAt: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double,
        altitudeMeters: Double?,
        speedMetersPerSecond: Double?
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.altitudeMeters = altitudeMeters
        self.speedMetersPerSecond = speedMetersPerSecond
    }
}
