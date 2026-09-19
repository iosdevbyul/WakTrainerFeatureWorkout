//
//  WorkoutFeatureResult.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Foundation

public struct WorkoutFeatureResult: Sendable {

    public let workoutID: String
    public let workoutName: String
    public let duration: TimeInterval
    public let distanceMeters: Double
    public let activeCalories: Double
    public let stepCount: Double

    public init(
        workoutID: String,
        workoutName: String,
        duration: TimeInterval,
        distanceMeters: Double,
        activeCalories: Double,
        stepCount: Double
    ) {
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
        self.stepCount = stepCount
    }
}
