import Foundation
import WakTrainerDomainWorkout

@MainActor
final class StrengthExerciseSelectionViewModel:
    ObservableObject {

    @Published private(set) var exercises:
        [StrengthExerciseDefinition] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage:
        String?

    private let fetchExercisesUseCase:
        FetchStrengthExercisesUseCase

    init(
        fetchExercisesUseCase:
            FetchStrengthExercisesUseCase
    ) {
        self.fetchExercisesUseCase =
            fetchExercisesUseCase
    }

    func loadExercises() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            exercises =
                try await
                fetchExercisesUseCase
                    .execute()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}
