import WakTrainerCoreModels
import WakTrainerDomainWorkout

struct LocalStrengthExerciseCatalogRepository:
    StrengthExerciseCatalogRepository {

    func fetchExercises() async throws
        -> [StrengthExerciseDefinition] {
        [
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
