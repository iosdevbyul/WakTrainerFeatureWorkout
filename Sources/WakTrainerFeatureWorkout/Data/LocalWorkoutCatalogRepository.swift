//
//  LocalWorkoutCatalogRepository.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import WakTrainerCoreModels
import WakTrainerDomainWorkout

struct LocalWorkoutCatalogRepository:
    WorkoutCatalogRepository {

    func fetchWorkouts() async throws
        -> [WorkoutDefinition] {
        [
            WorkoutDefinition(
                id: "running",
                name: "Running",
                category: .cardio,
                type: .dynamicWorkout
            ),
            WorkoutDefinition(
                id: "walking",
                name: "Walking",
                category: .cardio,
                type: .dynamicWorkout
            ),
            WorkoutDefinition(
                id: "cycling",
                name: "Cycling",
                category: .cardio,
                type: .dynamicWorkout
            ),
            WorkoutDefinition(
                id: "strength_training",
                name: "Strength Training",
                category: .strength,
                type: .staticWorkout
            )
        ]
    }
}
