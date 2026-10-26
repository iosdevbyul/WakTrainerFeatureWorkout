import Combine
import Foundation
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@MainActor
final class WorkoutPauseRestoreViewModel: ObservableObject {
    @Published private(set) var session: WorkoutSession
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var undoToken: WorkoutPauseRestoreUndoToken?

    private let service: WorkoutPauseRestorePersistenceService?

    init(
        session: WorkoutSession,
        storage: (any WorkoutPauseRestoreStorage)?
    ) {
        self.session = session
        self.service = storage.map {
            WorkoutPauseRestorePersistenceService(storage: $0)
        }
    }

    var canRestore: Bool {
        service != nil && !isSaving &&
        session.timing.endDate != nil &&
        !session.timing.pauseIntervals.isEmpty
    }

    var canUndo: Bool {
        undoToken != nil && service != nil && !isSaving
    }

    func restore(from start: Date, to end: Date) async {
        guard let service, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let token = try await service.restore(
                sessionID: session.id,
                from: start,
                to: end
            )
            session = token.after
            undoToken = token
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undo() async {
        guard let service, let token = undoToken, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await service.undo(token)
            session = token.before
            undoToken = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
