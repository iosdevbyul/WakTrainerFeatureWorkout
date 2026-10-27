import WakTrainerCoreModels
import WakTrainerDomainWorkout

/// A practical selection of activities informed by the 2024 Adult Compendium.
/// Outdoor activities use GPS route tracking; indoor activities retain elapsed
/// time and sensor metrics without recording an invalid stationary GPS trace.
struct LocalWorkoutCatalogRepository: WorkoutCatalogRepository {
    func fetchWorkouts() async throws -> [WorkoutDefinition] {
        [
            WorkoutDefinition(id: "running", name: "Running", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "walking", name: "Walking", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "cycling", name: "Cycling", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "strength_training", name: "Strength Training", category: .strength, type: .staticWorkout),
            WorkoutDefinition(id: "hiking", name: "Hiking", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "trail_running", name: "Trail Running", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "jogging", name: "Jogging", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "race_walking", name: "Race Walking", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "mountain_biking", name: "Mountain Biking", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "road_cycling", name: "Road Cycling", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "outdoor_skating", name: "Outdoor Skating", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "rollerblading", name: "Rollerblading", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "cross_country_skiing", name: "Cross-Country Skiing", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "snowshoeing", name: "Snowshoeing", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "outdoor_rowing", name: "Outdoor Rowing", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "paddleboarding", name: "Paddleboarding", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "kayaking", name: "Kayaking", category: .cardio, type: .dynamicWorkout),
            WorkoutDefinition(id: "treadmill_running", name: "Treadmill Running", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "treadmill_walking", name: "Treadmill Walking", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "indoor_cycling", name: "Indoor Cycling", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "spin_class", name: "Spin Class", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "elliptical", name: "Elliptical", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "stair_climber", name: "Stair Climber", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "rowing_machine", name: "Rowing Machine", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "jump_rope", name: "Jump Rope", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "aerobics", name: "Aerobics", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "step_aerobics", name: "Step Aerobics", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "dance_cardio", name: "Dance Cardio", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "zumba", name: "Zumba", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "hiit_cardio", name: "HIIT Cardio", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "circuit_cardio", name: "Circuit Cardio", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "boxing_fitness", name: "Boxing Fitness", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "kickboxing_fitness", name: "Kickboxing Fitness", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "indoor_swimming", name: "Pool Swimming", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "water_aerobics", name: "Water Aerobics", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "pilates", name: "Pilates", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "indoor_climbing", name: "Indoor Climbing", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "stationary_ski_erg", name: "Ski Erg", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "recumbent_bike", name: "Recumbent Bike", category: .cardio, type: .staticWorkout),
            WorkoutDefinition(id: "arm_ergometer", name: "Arm Ergometer", category: .cardio, type: .staticWorkout)
        ]
    }
}
