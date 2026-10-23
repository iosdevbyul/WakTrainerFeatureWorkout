import Foundation
import WakTrainerCoreModels
import WakTrainerServiceWorkoutStorage

/// Uploads only completed, locally persisted sessions. Failed uploads remain
/// in SwiftData and are retried on the next explicit sync trigger.
@MainActor
public final class WorkoutServerSync {
    private let repository: SwiftDataWorkoutSessionRepository
    private let baseURL: URL
    private let accessToken: () -> String?
    private let session: URLSession
    private var isSyncing = false

    public init(
        baseURL: URL,
        ownerUserID: UUID,
        accessToken: @escaping () -> String?,
        session: URLSession = .shared
    ) throws {
        self.repository = try SwiftDataWorkoutSessionRepository(ownerUserID: ownerUserID)
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.session = session
    }

    public func syncPendingSessions() async {
        guard !isSyncing, let token = accessToken(), !token.isEmpty else {
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        guard let pending = try? await repository.fetchPendingUploads() else {
            return
        }

        for stored in pending {
            if Task.isCancelled { return }
            do {
                try await upload(stored.session, token: token)
                try Task.checkCancellation()
                try await repository.updateSyncState(
                    for: stored.session.id, to: .synced
                )
            } catch is CancellationError {
                // Retain the pending record for a future explicit retry.
                return
            } catch {
                try? await repository.updateSyncState(
                    for: stored.session.id, to: .failed
                )
            }
        }
    }

    private func upload(_ workout: WorkoutSession, token: String) async throws {
        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("v1")
                .appendingPathComponent("workouts")
                .appendingPathComponent(workout.id.uuidString)
        )
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(workout)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw WorkoutUploadError.rejected
        }
    }
}

public enum WorkoutUploadError: Error {
    case rejected
}
