import Foundation

/// Preferences are keyed by stable exercise IDs and survive catalog additions.
@MainActor
final class StrengthExerciseListPreferences: ObservableObject {
    enum SortMode: String, CaseIterable, Identifiable {
        case mostUsed = "Most used"
        case custom = "My order"
        var id: String { rawValue }
    }

    @Published private(set) var favorites: Set<String>
    @Published private(set) var usageCounts: [String: Int]
    @Published private(set) var customOrder: [String]
    @Published var favoritesOnly = false
    @Published var sortMode: SortMode = .mostUsed

    private let defaults: UserDefaults
    private let prefix = "waktrainer.strength.exercise."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Set(defaults.stringArray(forKey: prefix + "favorites") ?? [])
        usageCounts = defaults.dictionary(forKey: prefix + "usageCounts") as? [String: Int] ?? [:]
        customOrder = defaults.stringArray(forKey: prefix + "customOrder") ?? []
    }

    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }
    func usageCount(_ id: String) -> Int { usageCounts[id, default: 0] }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        defaults.set(favorites.sorted(), forKey: prefix + "favorites")
    }

    /// Counts exercise selections. Does not claim to count completed workout sessions.
    func recordSelection(_ id: String) {
        usageCounts[id, default: 0] += 1
        defaults.set(usageCounts, forKey: prefix + "usageCounts")
    }

    func ordered<T>(_ items: [T], id: (T) -> String, name: (T) -> String) -> [T] {
        let filtered = favoritesOnly ? items.filter { favorites.contains(id($0)) } : items
        return filtered.sorted { lhs, rhs in
            let a = id(lhs), b = id(rhs)
            switch sortMode {
            case .mostUsed:
                let left = usageCount(a), right = usageCount(b)
                return left == right ? name(lhs).localizedStandardCompare(name(rhs)) == .orderedAscending : left > right
            case .custom:
                let left = customOrder.firstIndex(of: a) ?? Int.max
                let right = customOrder.firstIndex(of: b) ?? Int.max
                return left == right ? name(lhs).localizedStandardCompare(name(rhs)) == .orderedAscending : left < right
            }
        }
    }

    func move(_ ids: [String], from source: IndexSet, to destination: Int) {
        var next = ids
        next.move(fromOffsets: source, toOffset: destination)
        // Keep ordering for exercises in other muscle groups.
        let moved = Set(ids)
        customOrder.removeAll { moved.contains($0) }
        customOrder.append(contentsOf: next)
        defaults.set(customOrder, forKey: prefix + "customOrder")
    }
}
