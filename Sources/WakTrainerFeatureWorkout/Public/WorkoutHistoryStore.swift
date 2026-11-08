import Combine
import Foundation
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceWorkoutStorage

@MainActor
public final class WorkoutHistoryStore: ObservableObject {

    @Published
    public private(set) var sessions:
        [StoredWorkoutSession] = []

    @Published
    public private(set) var isLoading = false

    @Published
    public private(set) var errorMessage: String?

    private let repositoryProvider:
        () throws -> any WorkoutSessionRepository

    public convenience init(ownerUserID: UUID? = nil) {
        self.init(
            repositoryProvider: {
                try SwiftDataWorkoutSessionRepository(ownerUserID: ownerUserID)
            }
        )
    }

    init(
        repositoryProvider:
            @escaping () throws ->
                any WorkoutSessionRepository
    ) {
        self.repositoryProvider =
            repositoryProvider
    }

    public var latestSession: WorkoutSession? {
        sessions.first?.session
    }

    public func reload() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let repository =
                try repositoryProvider()

            sessions =
                try await repository
                    .fetchSessions()
                    .filter {
                        $0.persistenceState
                            == .completed
                    }
                    .sorted {
                        $0.session.timing.startDate
                            >
                        $1.session.timing.startDate
                    }
        } catch {
            sessions = []
            errorMessage =
                error.localizedDescription
        }
    }

    public func highlightedDates(
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(
            sessions.map {
                calendar.startOfDay(
                    for:
                        $0.session.timing
                            .startDate
                )
            }
        )
    }
}


// Explicit user-triggered export. The owner-scoped history store is the sole source;
// sensitive routes, biometric samples and profile identifiers are intentionally excluded.
public enum WorkoutDashboardExportError: Error {
    case invalidDuration
    case invalidDistance
    case unsupportedWorkoutType
    case tooManySessions
    case tooLarge
}

@MainActor
public extension WorkoutHistoryStore {
    func dashboardExportV2() throws -> Data {
        guard sessions.count <= 500 else {
            throw WorkoutDashboardExportError.tooManySessions
        }

        struct ExportSession: Encodable {
            let session_id: String
            let started_at: String
            let activity_type: String
            let duration_seconds: Double
            let distance_meters: Double
        }
        struct ExportEnvelope: Encodable {
            let schema_version: Int
            let sessions: [ExportSession]
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let records = try sessions.map { stored -> ExportSession in
            let session = stored.session
            guard session.timing.activeDuration.isFinite,
                  (0...86_400).contains(session.timing.activeDuration) else {
                throw WorkoutDashboardExportError.invalidDuration
            }
            let distance = session.health.summary.distanceMeters ?? 0
            guard distance.isFinite, (0...1_000_000).contains(distance) else {
                throw WorkoutDashboardExportError.invalidDistance
            }
            let name = session.workout.workoutID.lowercased()
            let activity: String
            if name.contains("running") || name == "run" {
                activity = "running"
            } else if name.contains("walking") || name == "walk" {
                activity = "walking"
            } else if name.contains("cycling") || name.contains("bike") {
                activity = "cycling"
            } else if name.contains("climb") {
                activity = "climbing"
            } else if name.contains("strength") || name.contains("weight") || name.contains("gym") {
                activity = "strength"
            } else {
                throw WorkoutDashboardExportError.unsupportedWorkoutType
            }
            return ExportSession(
                session_id: session.id.uuidString.lowercased(),
                started_at: iso.string(from: session.timing.startDate),
                activity_type: activity,
                duration_seconds: session.timing.activeDuration,
                distance_meters: distance
            )
        }
        let data = try JSONEncoder().encode(
            ExportEnvelope(schema_version: 2, sessions: records)
        )
        guard data.count <= 128 * 1024 else {
            throw WorkoutDashboardExportError.tooLarge
        }
        return data
    }
}
