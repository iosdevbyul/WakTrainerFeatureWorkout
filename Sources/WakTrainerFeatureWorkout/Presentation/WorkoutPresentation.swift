import WakTrainerCoreModels
import WakTrainerDomainWorkout

extension WorkoutDefinition {

    var launcherSystemImage: String {
        switch id {
        case "running":
            "figure.run"

        case "walking":
            "figure.walk"

        case "cycling":
            "bicycle"

        case "strength_training":
            "figure.strengthtraining.traditional"

        default:
            category == .strength
                ? "figure.strengthtraining.traditional"
                : "figure.mixed.cardio"
        }
    }
}

extension StrengthEquipment {

    var displayName: String {
        switch self {
        case .barbell:
            "Barbell"
        case .dumbbell:
            "Dumbbell"
        case .bodyweight:
            "Bodyweight"
        case .machine:
            "Machine"
        case .kettlebell:
            "Kettlebell"
        case .cable:
            "Cable"
        case .resistanceBand:
            "Resistance Band"
        case .other:
            "Other"
        }
    }

    var requiresWeightInput: Bool {
        switch self {
        case .barbell,
             .dumbbell,
             .machine,
             .kettlebell,
             .cable:
            true

        case .bodyweight,
             .resistanceBand,
             .other:
            false
        }
    }
}
