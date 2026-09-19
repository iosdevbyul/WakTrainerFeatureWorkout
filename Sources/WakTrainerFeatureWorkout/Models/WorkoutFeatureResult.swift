//
//  WorkoutFeatureResult.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Foundation
import WakTrainerDomainWorkout

public struct WorkoutFeatureResult: Sendable {

    public let workout: WorkoutDefinition
    public let duration: TimeInterval
    public let distanceMeters: Double
    public let activeCalories: Double
    public let stepCount: Double

    public init(
        workout: WorkoutDefinition,
        duration: TimeInterval,
        distanceMeters: Double,
        activeCalories: Double,
        stepCount: Double
    ) {
        self.workout = workout
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
        self.stepCount = stepCount
    }
}
