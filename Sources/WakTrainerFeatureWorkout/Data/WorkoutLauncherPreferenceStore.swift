import Foundation

protocol WorkoutLauncherPreferenceStore: Sendable {
    var favoriteWorkoutIDs: Set<String> { get }

    func setFavorite(
        _ isFavorite: Bool,
        workoutID: String
    )
}

final class UserDefaultsWorkoutLauncherPreferenceStore:
    WorkoutLauncherPreferenceStore,
    @unchecked Sendable {

    private let userDefaults: UserDefaults
    private let key =
        "WakTrainerFeatureWorkout.favoriteWorkoutIDs"

    init(
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
    }

    var favoriteWorkoutIDs: Set<String> {
        Set(
            userDefaults.stringArray(
                forKey: key
            ) ?? []
        )
    }

    func setFavorite(
        _ isFavorite: Bool,
        workoutID: String
    ) {
        var favorites =
            favoriteWorkoutIDs

        if isFavorite {
            favorites.insert(workoutID)
        } else {
            favorites.remove(workoutID)
        }

        userDefaults.set(
            favorites.sorted(),
            forKey: key
        )
    }
}
