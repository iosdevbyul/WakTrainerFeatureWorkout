/// Display/input preference supplied by the host app. Stored workout weights remain kilograms.
public enum WorkoutWeightUnit: String, Codable, Sendable, CaseIterable {
    case kg
    case lb

    public func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kg: kilograms
        case .lb: kilograms * 2.2046226218487757
        }
    }

    public func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lb: value / 2.2046226218487757
        }
    }
}
