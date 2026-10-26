import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("Workout history pause Restore")
struct WorkoutPauseRestoreViewModelTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func session() -> WorkoutSession {
        WorkoutSession(
            workout: WorkoutIdentity(
                workoutID: "cycling",
                name: "Cycling",
                category: "cardio",
                type: .dynamicWorkout
            ),
            timing: WorkoutTiming(
                startDate: start,
                endDate: start.addingTimeInterval(3600),
                elapsedDuration: 3600,
                activeDuration: 2700,
                pausedDuration: 900,
                pauseIntervals: [
                    WorkoutPauseInterval(
                        startDate: start.addingTimeInterval(1200),
                        endDate: start.addingTimeInterval(2100)
                    )
                ]
            )
        )
    }

    @Test("Restore updates history report session and Undo returns the original")
    func restoreThenUndo() async {
        let original = session()
        let storage = MockPauseStorage(session: original)
        let model = WorkoutPauseRestoreViewModel(session: original, storage: storage)
        await model.restore(
            from: start.addingTimeInterval(1200),
            to: start.addingTimeInterval(1800)
        )
        #expect(model.session.timing.activeDuration == 3300)
        #expect(model.session.timing.pausedDuration == 300)
        #expect(model.canUndo)
        #expect(storage.session == model.session)
        await model.undo()
        #expect(model.session == original)
        #expect(storage.session == original)
        #expect(!model.canUndo)
    }

    @Test("Without atomic storage, restore remains unavailable")
    func noStorageDisablesRestore() {
        let model = WorkoutPauseRestoreViewModel(session: session(), storage: nil)
        #expect(!model.canRestore)
        #expect(!model.canUndo)
    }

    @Test("Stale Undo does not overwrite newer stored data")
    func staleUndoFailsSafely() async {
        let original = session()
        let storage = MockPauseStorage(session: original)
        let model = WorkoutPauseRestoreViewModel(session: original, storage: storage)
        await model.restore(
            from: start.addingTimeInterval(1200),
            to: start.addingTimeInterval(1800)
        )
        storage.session?.timing.activeDuration += 1
        await model.undo()
        #expect(model.errorMessage != nil)
        #expect(model.canUndo)
        #expect(storage.session?.timing.activeDuration == 3301)
    }
}

@MainActor
private final class MockPauseStorage: WorkoutPauseRestoreStorage {
    var session: WorkoutSession?

    init(session: WorkoutSession?) {
        self.session = session
    }

    func fetchCompletedSession(id: UUID) async throws -> WorkoutSession? {
        session?.id == id ? session : nil
    }

    func compareAndReplaceCompleted(
        expected: WorkoutSession,
        replacement: WorkoutSession
    ) async throws -> Bool {
        guard session == expected else { return false }
        session = replacement
        return true
    }
}
