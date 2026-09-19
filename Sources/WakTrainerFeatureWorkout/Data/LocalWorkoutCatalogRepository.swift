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
                name: "스쿼트",
                category: .strength,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "bench_press",
                name: "벤치프레스",
                category: .strength,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "running",
                name: "달리기",
                category: .cardio,
                type: .dynamicWorkout
            ),
            WorkoutDefinition(
                id: "walking",
                name: "걷기",
                category: .cardio,
                type: .dynamicWorkout
            ),
            WorkoutDefinition(
                id: "indoor_cycling",
                name: "실내 자전거",
                category: .cardio,
                type: .staticWorkout
            ),
            WorkoutDefinition(
                id: "outdoor_cycling",
                name: "야외 자전거",
                category: .cardio,
                type: .dynamicWorkout
            )
        ]
    }
}
