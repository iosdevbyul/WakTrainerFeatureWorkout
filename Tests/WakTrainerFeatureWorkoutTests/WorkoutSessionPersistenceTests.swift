import Foundation
import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("Workout session persistence")
struct WorkoutSessionPersistenceTests {

    @Test("legacy strength workout restores inside strength training session")
    func legacyStrengthWorkoutRestoresSessionState()
        async throws {
        let repository =
            MockWorkoutSessionRepository()
        let start = Date(
            timeIntervalSince1970:
                1_800_000_000
        )
        let sessionID = UUID()

        let persistedSession =
            WorkoutSession(
                id: sessionID,
                workout:
                    WorkoutIdentity(
                        workoutID:
                            "squat",
                        name:
                            "Squat",
                        category:
                            "strength",
                        type:
                            .staticWorkout
                    ),
                timing:
                    WorkoutTiming(
                        startDate: start,
                        endDate: nil,
                        elapsedDuration:
                            320,
                        activeDuration:
                            280,
                        pausedDuration:
                            40
                    ),
                exerciseRecords: [
                    WorkoutExerciseRecord(
                        exerciseID:
                            "squat",
                        name:
                            "Squat",
                        kind:
                            .strength,
                        strengthEquipment:
                            nil,
                        startDate:
                            start,
                        endDate: nil,
                        strengthSets: [
                            StrengthSetRecord(
                                setNumber: 1,
                                weightKilograms:
                                    100,
                                repetitions: 5,
                                restDuration:
                                    90,
                                isCompleted:
                                    true
                            )
                        ]
                    )
                ],
                health:
                    WorkoutHealthData(
                        summary:
                            WorkoutHealthSummary(
                                averageHeartRate:
                                    125,
                                activeCalories:
                                    180,
                                stepCount:
                                    450,
                                distanceMeters:
                                    600
                            )
                    )
            )

        let stored =
            StoredWorkoutSession(
                session:
                    persistedSession,
                persistenceState:
                    .inProgress,
                syncState:
                    .pending,
                updatedAt:
                    start.addingTimeInterval(
                        320
                    )
            )

        let viewModel =
            WorkoutSessionViewModel(
                workout:
                    strengthWorkout,
                restoredSession:
                    stored,
                healthKitManager:
                    PersistenceHealthManager(),
                sessionRepository:
                    repository,
                timerManager:
                    TimerManager(),
                restTimerManager:
                    TimerManager()
            )

        #expect(
            viewModel.timerState
                == .paused
        )
        #expect(
            abs(
                viewModel.elapsedTime
                - 280
            ) < 0.001
        )
        #expect(
            viewModel.activeStrengthExercise?
                .id
                == "squat"
        )
        #expect(
            viewModel.activeStrengthEquipment
                == nil
        )
        #expect(
            viewModel.strengthSets.count
                == 1
        )
        #expect(
            viewModel.activeCalories
                == 180
        )

        let completed =
            await viewModel
                .finishWorkout()

        #expect(
            completed.id
                == sessionID
        )
        #expect(
            completed.workout.workoutID
                == "strength_training"
        )
        #expect(
            completed.exerciseRecords
                .first?
                .exerciseID
                == "squat"
        )
        #expect(
            completed.exerciseRecords
                .first?
                .strengthEquipment
                == nil
        )
        #expect(
            completed.exerciseRecords
                .first?
                .strengthSets.count
                == 1
        )
        #expect(
            completed.health.summary
                .activeCalories
                == 180
        )
        #expect(
            repository.completed
                .last?.id
                == sessionID
        )
    }

    @Test("checkpoint and completed strength session share one top level session ID")
    func checkpointAndCompletedSessionShareID()
        async throws {
        let repository =
            MockWorkoutSessionRepository()

        let viewModel =
            WorkoutSessionViewModel(
                workout:
                    strengthWorkout,
                healthKitManager:
                    PersistenceHealthManager(),
                sessionRepository:
                    repository,
                timerManager:
                    TimerManager(),
                restTimerManager:
                    TimerManager()
            )

        #expect(
            viewModel.beginStrengthExercise(
                squatDefinition,
                equipment:
                    .barbell
            )
        )

        await viewModel.startWorkout()

        let checkpoint =
            try #require(
                repository.checkpoints
                    .last
            )

        let recorded =
            viewModel
                .recordStrengthSet(
                    weightKilograms:
                        80,
                    repetitions:
                        8
                )
        #expect(recorded)

        await Task.yield()

        let session =
            await viewModel
                .finishWorkout()
        let completed =
            try #require(
                repository.completed
                    .last
            )

        #expect(
            completed.id
                == checkpoint.id
        )
        #expect(
            completed.id
                == session.id
        )
        #expect(
            completed.workout.workoutID
                == "strength_training"
        )
        #expect(
            completed.timing.endDate
                != nil
        )
        #expect(
            completed.exerciseRecords
                .count
                == 1
        )
        #expect(
            completed.exerciseRecords
                .first?
                .exerciseID
                == "squat"
        )
        #expect(
            completed.exerciseRecords
                .first?
                .strengthEquipment
                == .barbell
        )
        #expect(
            completed.exerciseRecords
                .first?
                .strengthSets.count
                == 1
        )
    }

    private var strengthWorkout:
        WorkoutDefinition {
        WorkoutDefinition(
            id: "strength_training",
            name: "Strength Training",
            category: .strength,
            type: .staticWorkout
        )
    }

    private var squatDefinition:
        StrengthExerciseDefinition {
        StrengthExerciseDefinition(
            id: "squat",
            name: "Squat",
            supportedEquipment: [
                .barbell,
                .dumbbell,
                .bodyweight
            ]
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

    func fetchCompletedSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [StoredWorkoutSession] {
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
