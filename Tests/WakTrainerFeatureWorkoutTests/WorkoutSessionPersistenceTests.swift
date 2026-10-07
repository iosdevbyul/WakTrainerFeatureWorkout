import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("Workout session persistence")
struct WorkoutSessionPersistenceTests {

    @Test("start creates checkpoint and finish promotes the same session ID")
    func checkpointAndCompletedSessionShareID() async throws {
        let repository = MockWorkoutSessionRepository()
        let viewModel = WorkoutSessionViewModel(
            workout: WorkoutDefinition(
                id: "squat",
                name: "스쿼트",
                category: .strength,
                type: .staticWorkout
            ),
            healthKitManager: PersistenceHealthManager(),
            sessionRepository: repository,
            timerManager: TimerManager(),
            restTimerManager: TimerManager()
        )

        await viewModel.startWorkout()

        let checkpoint = try #require(
            repository.checkpoints.last
        )

        let recorded = viewModel.recordStrengthSet(
            weightKilograms: 80,
            repetitions: 8
        )
        #expect(recorded)

        await Task.yield()

        let session = await viewModel.finishWorkout()
        let completed = try #require(
            repository.completed.last
        )

        #expect(completed.id == checkpoint.id)
        #expect(completed.id == session.id)
        #expect(completed.timing.endDate != nil)
        #expect(
            completed.exerciseRecords.first?.strengthSets.count == 1
        )
    }
}

@MainActor
private final class MockWorkoutSessionRepository:
    WorkoutSessionRepository {

    private(set) var checkpoints: [WorkoutSession] = []
    private(set) var completed: [WorkoutSession] = []

    func saveCheckpoint(
        _ session: WorkoutSession
    ) async throws {
        checkpoints.append(session)
    }

    func saveCompleted(
        _ session: WorkoutSession
    ) async throws {
        completed.append(session)
    }

    func fetchSession(
        id: UUID
    ) async throws -> StoredWorkoutSession? {
        nil
    }

    func fetchSessions() async throws -> [StoredWorkoutSession] {
        []
    }

    func fetchIncompleteSessions() async throws -> [StoredWorkoutSession] {
        []
    }

    func deleteSession(
        id: UUID
    ) async throws {}

    func deleteAllSessions() async throws {}
}

private final class PersistenceHealthManager:
    HealthKitManagerProtocol,
    @unchecked Sendable {

    var isAuthorized: Bool {
        get async {
            true
        }
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func startObservingData() -> AsyncStream<HealthSnapshot> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func stopObservingData() async {}

    func fetchWorkoutHealthData(
        from startDate: Date,
        to endDate: Date
    ) async throws -> WorkoutHealthData {
        WorkoutHealthData()
    }
}
