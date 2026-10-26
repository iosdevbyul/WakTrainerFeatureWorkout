import WakTrainerCoreModels
import WakTrainerDomainWorkout

struct LocalStrengthExerciseCatalogRepository:
    StrengthExerciseCatalogRepository {

    func fetchExercises() async throws
        -> [StrengthExerciseDefinition] {
        [
            StrengthExerciseDefinition(
                id: "leg_press",
                name: "Leg Press",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "leg_extension",
                name: "Leg Extension",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "seated_leg_curl",
                name: "Seated Leg Curl",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "lying_leg_curl",
                name: "Lying Leg Curl",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "romanian_deadlift",
                name: "Romanian Deadlift",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "bulgarian_split_squat",
                name: "Bulgarian Split Squat",
                supportedEquipment: [.dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "walking_lunge",
                name: "Walking Lunge",
                supportedEquipment: [.dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "hip_thrust",
                name: "Hip Thrust",
                supportedEquipment: [.barbell, .machine]
            ),
            StrengthExerciseDefinition(
                id: "calf_raise",
                name: "Calf Raise",
                supportedEquipment: [.machine, .dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "hack_squat",
                name: "Hack Squat",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "goblet_squat",
                name: "Goblet Squat",
                supportedEquipment: [.kettlebell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "chest_press",
                name: "Chest Press",
                supportedEquipment: [.machine, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "incline_bench_press",
                name: "Incline Bench Press",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "chest_fly",
                name: "Chest Fly",
                supportedEquipment: [.machine, .cable, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "push_up",
                name: "Push Up",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "seated_cable_row",
                name: "Seated Cable Row",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "pull_up",
                name: "Pull Up",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "assisted_pull_up",
                name: "Assisted Pull Up",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "single_arm_row",
                name: "Single Arm Row",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "lateral_raise",
                name: "Lateral Raise",
                supportedEquipment: [.dumbbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "rear_delt_fly",
                name: "Rear Delt Fly",
                supportedEquipment: [.machine, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "face_pull",
                name: "Face Pull",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "hammer_curl",
                name: "Hammer Curl",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "preacher_curl",
                name: "Preacher Curl",
                supportedEquipment: [.machine, .barbell]
            ),
            StrengthExerciseDefinition(
                id: "triceps_pushdown",
                name: "Triceps Pushdown",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "skull_crusher",
                name: "Skull Crusher",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "cable_crunch",
                name: "Cable Crunch",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "hanging_leg_raise",
                name: "Hanging Leg Raise",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "squat",
                name: "Squat",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .bodyweight
                ]
            ),
            StrengthExerciseDefinition(
                id: "bench_press",
                name: "Bench Press",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .machine
                ]
            ),
            StrengthExerciseDefinition(
                id: "deadlift",
                name: "Deadlift",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .kettlebell
                ]
            ),
            StrengthExerciseDefinition(
                id: "shoulder_press",
                name: "Shoulder Press",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .machine
                ]
            ),
            StrengthExerciseDefinition(
                id: "lat_pulldown",
                name: "Lat Pulldown",
                supportedEquipment: [
                    .cable,
                    .machine
                ]
            ),
            StrengthExerciseDefinition(
                id: "biceps_curl",
                name: "Biceps Curl",
                supportedEquipment: [.dumbbell, .barbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "triceps_extension",
                name: "Triceps Extension",
                supportedEquipment: [.dumbbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "crunch",
                name: "Crunch",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "plank",
                name: "Plank",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "barbell_row",
                name: "Row",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .cable
                ]
            )
        ]
    }
}
