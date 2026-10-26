import Testing
import Foundation
@testable import WakTrainerFeatureWorkout

@MainActor
struct StrengthExerciseListPreferencesTests {
    @Test func favoritesAndUsagePersistAcrossInstances() {
        let suite = "WakTrainerExercisePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = StrengthExerciseListPreferences(defaults: defaults)
        first.toggleFavorite("leg_extension")
        first.recordSelection("leg_extension")
        first.recordSelection("leg_extension")
        let second = StrengthExerciseListPreferences(defaults: defaults)
        #expect(second.isFavorite("leg_extension"))
        #expect(second.usageCount("leg_extension") == 2)
        #expect(!second.isFavorite("squat"))
    }

    @Test func customOrderPersistsAndFavoritesFilter() {
        let suite = "WakTrainerExerciseOrderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = StrengthExerciseListPreferences(defaults: defaults)
        first.sortMode = .custom
        first.move(["a", "b", "c"], from: IndexSet(integer: 2), to: 0)
        let second = StrengthExerciseListPreferences(defaults: defaults)
        second.sortMode = .custom
        #expect(second.ordered(["a", "b", "c"], id: { $0 }, name: { $0 }) == ["c", "a", "b"])
        second.toggleFavorite("b")
        second.favoritesOnly = true
        #expect(second.ordered(["a", "b", "c"], id: { $0 }, name: { $0 }) == ["b"])
    }
}
