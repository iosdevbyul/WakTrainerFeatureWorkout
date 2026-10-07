//
//  LocalWorkoutCatalogRepository.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import WakTrainerCoreModels
import WakTrainerDomainWorkout

struct LocalWorkoutCatalogRepository: WorkoutCatalogRepository {

    func fetchWorkouts() async throws -> [WorkoutDefinition] {
        [
            WorkoutDefinition(
                id: "squat",
                name: "Squat",
                category: .strength,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "bench_press",
                name: "Bench Press",
                category: .strength,
                type: .staticWorkout
            ),
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
                id: "indoor_cycling",
                name: "Indoor Cycling",
                category: .cardio,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "outdoor_cycling",
                name: "Outdoor Cycling",
                category: .cardio,
                type: .dynamicWorkout
            )
        ]
    }
}
