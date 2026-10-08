/// The host uses its place recognition result to select how a strength session collects location.
/// A registered place is resolved by the host. The feature never starts GPS in that case.
/// The host must persist registered-place identity separately until the workout domain model
/// supports a dedicated workout-place field.
public enum StrengthWorkoutLocationPolicy: Sendable, Equatable {
    case registeredPlace
    case singleLocation
    case disabled
}
