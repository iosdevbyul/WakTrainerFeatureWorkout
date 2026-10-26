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
                id: "smith_machine_squat",
                name: "Smith Machine Squat",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "front_squat",
                name: "Front Squat",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "sumo_squat",
                name: "Sumo Squat",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "box_squat",
                name: "Box Squat",
                supportedEquipment: [.barbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "split_squat",
                name: "Split Squat",
                supportedEquipment: [.dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "reverse_lunge",
                name: "Reverse Lunge",
                supportedEquipment: [.dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "lateral_lunge",
                name: "Lateral Lunge",
                supportedEquipment: [.dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "step_up",
                name: "Step Up",
                supportedEquipment: [.dumbbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "sissy_squat",
                name: "Sissy Squat",
                supportedEquipment: [.bodyweight, .machine]
            ),
            StrengthExerciseDefinition(
                id: "single_leg_press",
                name: "Single Leg Press",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "vertical_leg_press",
                name: "Vertical Leg Press",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "pendulum_squat",
                name: "Pendulum Squat",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "belt_squat",
                name: "Belt Squat",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "hip_abduction",
                name: "Hip Abduction",
                supportedEquipment: [.machine, .cable, .resistanceBand]
            ),
            StrengthExerciseDefinition(
                id: "hip_adduction",
                name: "Hip Adduction",
                supportedEquipment: [.machine, .cable]
            ),
            StrengthExerciseDefinition(
                id: "cable_kickback",
                name: "Cable Glute Kickback",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "glute_bridge",
                name: "Glute Bridge",
                supportedEquipment: [.barbell, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "single_leg_glute_bridge",
                name: "Single Leg Glute Bridge",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "nordic_curl",
                name: "Nordic Hamstring Curl",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "standing_leg_curl",
                name: "Standing Leg Curl",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "single_leg_curl",
                name: "Single Leg Curl",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "good_morning",
                name: "Good Morning",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "cable_pull_through",
                name: "Cable Pull Through",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "single_leg_romanian_deadlift",
                name: "Single Leg Romanian Deadlift",
                supportedEquipment: [.dumbbell, .kettlebell]
            ),
            StrengthExerciseDefinition(
                id: "seated_calf_raise",
                name: "Seated Calf Raise",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "standing_calf_raise",
                name: "Standing Calf Raise",
                supportedEquipment: [.machine, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "donkey_calf_raise",
                name: "Donkey Calf Raise",
                supportedEquipment: [.machine, .bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "tibialis_raise",
                name: "Tibialis Raise",
                supportedEquipment: [.bodyweight, .machine]
            ),
            StrengthExerciseDefinition(
                id: "decline_bench_press",
                name: "Decline Bench Press",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "close_grip_bench_press",
                name: "Close Grip Bench Press",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "smith_machine_bench_press",
                name: "Smith Machine Bench Press",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "incline_machine_chest_press",
                name: "Incline Machine Chest Press",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "pec_deck",
                name: "Pec Deck",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "incline_dumbbell_fly",
                name: "Incline Dumbbell Fly",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "low_to_high_cable_fly",
                name: "Low to High Cable Fly",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "high_to_low_cable_fly",
                name: "High to Low Cable Fly",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "cable_chest_press",
                name: "Cable Chest Press",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "dumbbell_floor_press",
                name: "Dumbbell Floor Press",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "chest_dip",
                name: "Chest Dip",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "assisted_chest_dip",
                name: "Assisted Chest Dip",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "decline_push_up",
                name: "Decline Push Up",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "incline_push_up",
                name: "Incline Push Up",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "diamond_push_up",
                name: "Diamond Push Up",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "dumbbell_pullover",
                name: "Dumbbell Pullover",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "wide_grip_lat_pulldown",
                name: "Wide Grip Lat Pulldown",
                supportedEquipment: [.cable, .machine]
            ),
            StrengthExerciseDefinition(
                id: "close_grip_lat_pulldown",
                name: "Close Grip Lat Pulldown",
                supportedEquipment: [.cable, .machine]
            ),
            StrengthExerciseDefinition(
                id: "single_arm_lat_pulldown",
                name: "Single Arm Lat Pulldown",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "straight_arm_pulldown",
                name: "Straight Arm Pulldown",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "chest_supported_row",
                name: "Chest Supported Row",
                supportedEquipment: [.machine, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "t_bar_row",
                name: "T Bar Row",
                supportedEquipment: [.barbell, .machine]
            ),
            StrengthExerciseDefinition(
                id: "landmine_row",
                name: "Landmine Row",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "pendlay_row",
                name: "Pendlay Row",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "inverted_row",
                name: "Inverted Row",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "machine_high_row",
                name: "Machine High Row",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "single_arm_cable_row",
                name: "Single Arm Cable Row",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "reverse_grip_row",
                name: "Reverse Grip Row",
                supportedEquipment: [.barbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "rack_pull",
                name: "Rack Pull",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "back_extension",
                name: "Back Extension",
                supportedEquipment: [.bodyweight, .machine]
            ),
            StrengthExerciseDefinition(
                id: "weighted_back_extension",
                name: "Weighted Back Extension",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "shrug",
                name: "Shrug",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "cable_shrug",
                name: "Cable Shrug",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "arnold_press",
                name: "Arnold Press",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "seated_dumbbell_press",
                name: "Seated Dumbbell Shoulder Press",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "machine_shoulder_press",
                name: "Machine Shoulder Press",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "landmine_press",
                name: "Landmine Press",
                supportedEquipment: [.barbell]
            ),
            StrengthExerciseDefinition(
                id: "front_raise",
                name: "Front Raise",
                supportedEquipment: [.dumbbell, .barbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "cable_lateral_raise",
                name: "Cable Lateral Raise",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "machine_lateral_raise",
                name: "Machine Lateral Raise",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "lean_away_lateral_raise",
                name: "Lean Away Lateral Raise",
                supportedEquipment: [.dumbbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "reverse_pec_deck",
                name: "Reverse Pec Deck",
                supportedEquipment: [.machine]
            ),
            StrengthExerciseDefinition(
                id: "bent_over_rear_delt_raise",
                name: "Bent Over Rear Delt Raise",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "upright_row",
                name: "Upright Row",
                supportedEquipment: [.barbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "band_pull_apart",
                name: "Band Pull Apart",
                supportedEquipment: [.resistanceBand]
            ),
            StrengthExerciseDefinition(
                id: "external_rotation",
                name: "Cable External Rotation",
                supportedEquipment: [.cable, .resistanceBand]
            ),
            StrengthExerciseDefinition(
                id: "incline_dumbbell_curl",
                name: "Incline Dumbbell Curl",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "concentration_curl",
                name: "Concentration Curl",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "spider_curl",
                name: "Spider Curl",
                supportedEquipment: [.dumbbell, .barbell]
            ),
            StrengthExerciseDefinition(
                id: "cable_biceps_curl",
                name: "Cable Biceps Curl",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "reverse_curl",
                name: "Reverse Curl",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "zottman_curl",
                name: "Zottman Curl",
                supportedEquipment: [.dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "bayesian_curl",
                name: "Bayesian Cable Curl",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "overhead_triceps_extension",
                name: "Overhead Triceps Extension",
                supportedEquipment: [.dumbbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "rope_triceps_pushdown",
                name: "Rope Triceps Pushdown",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "single_arm_triceps_pushdown",
                name: "Single Arm Triceps Pushdown",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "triceps_dip",
                name: "Triceps Dip",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "bench_dip",
                name: "Bench Dip",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "triceps_kickback",
                name: "Triceps Kickback",
                supportedEquipment: [.dumbbell, .cable]
            ),
            StrengthExerciseDefinition(
                id: "wrist_curl",
                name: "Wrist Curl",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "reverse_wrist_curl",
                name: "Reverse Wrist Curl",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "farmers_carry",
                name: "Farmer's Carry",
                supportedEquipment: [.dumbbell, .kettlebell]
            ),
            StrengthExerciseDefinition(
                id: "ab_wheel_rollout",
                name: "Ab Wheel Rollout",
                supportedEquipment: [.other]
            ),
            StrengthExerciseDefinition(
                id: "reverse_crunch",
                name: "Reverse Crunch",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "bicycle_crunch",
                name: "Bicycle Crunch",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "dead_bug",
                name: "Dead Bug",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "bird_dog",
                name: "Bird Dog",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "russian_twist",
                name: "Russian Twist",
                supportedEquipment: [.bodyweight, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "side_plank",
                name: "Side Plank",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "pallof_press",
                name: "Pallof Press",
                supportedEquipment: [.cable, .resistanceBand]
            ),
            StrengthExerciseDefinition(
                id: "woodchop",
                name: "Cable Woodchop",
                supportedEquipment: [.cable]
            ),
            StrengthExerciseDefinition(
                id: "decline_sit_up",
                name: "Decline Sit Up",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "captains_chair_leg_raise",
                name: "Captain's Chair Leg Raise",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "hollow_body_hold",
                name: "Hollow Body Hold",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "mountain_climber",
                name: "Mountain Climber",
                supportedEquipment: [.bodyweight]
            ),
            StrengthExerciseDefinition(
                id: "kettlebell_swing",
                name: "Kettlebell Swing",
                supportedEquipment: [.kettlebell]
            ),
            StrengthExerciseDefinition(
                id: "turkish_get_up",
                name: "Turkish Get Up",
                supportedEquipment: [.kettlebell]
            ),
            StrengthExerciseDefinition(
                id: "thruster",
                name: "Thruster",
                supportedEquipment: [.barbell, .dumbbell]
            ),
            StrengthExerciseDefinition(
                id: "clean_and_press",
                name: "Clean and Press",
                supportedEquipment: [.barbell, .kettlebell]
            ),
            StrengthExerciseDefinition(
                id: "burpee",
                name: "Burpee",
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
