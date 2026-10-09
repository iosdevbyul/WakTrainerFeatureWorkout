import Foundation

/// A UI-independent snapshot of an in-progress workout, suitable for host integrations.
public struct WorkoutLiveSnapshot: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case cardio
        case strength
    }

    public enum Phase: String, Sendable {
        case running
        case paused
        case finished
    }

    public let kind: Kind
    public let phase: Phase
    public let workoutName: String
    public let elapsedSeconds: TimeInterval
    public let heartRateBPM: Double
    public let activeCalories: Double
    public let distanceMeters: Double
    public let steps: Double
    public let currentExerciseName: String?
    public let completedSets: Int

    public init(
        kind: Kind,
        phase: Phase,
        workoutName: String,
        elapsedSeconds: TimeInterval,
        heartRateBPM: Double,
        activeCalories: Double,
        distanceMeters: Double,
        steps: Double,
        currentExerciseName: String?,
        completedSets: Int
    ) {
        self.kind = kind
        self.phase = phase
        self.workoutName = workoutName
        self.elapsedSeconds = elapsedSeconds
        self.heartRateBPM = heartRateBPM
        self.activeCalories = activeCalories
        self.distanceMeters = distanceMeters
        self.steps = steps
        self.currentExerciseName = currentExerciseName
        self.completedSets = completedSets
    }
}
