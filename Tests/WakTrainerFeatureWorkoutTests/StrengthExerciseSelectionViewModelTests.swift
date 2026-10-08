import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
struct StrengthExerciseSelectionViewModelTests {

    @Test
    func loadExercisesReturnsStrengthExerciseCatalog()
        async {
        let expected = [
            StrengthExerciseDefinition(
                id: "squat",
                name: "Squat",
                supportedEquipment: [
                    .barbell,
                    .dumbbell,
                    .bodyweight
                ]
            ),
            StrengthExerciseDefinition(
                id: "bench_press",
                name: "Bench Press",
                supportedEquipment: [
                    .barbell,
                    .dumbbell
                ]
            )
        ]

        let viewModel =
            StrengthExerciseSelectionViewModel(
                fetchExercisesUseCase:
                    FetchStrengthExercisesUseCase(
                        repository:
                            TestStrengthExerciseRepository(
                                exercises:
                                    expected
                            )
                    )
            )

        await viewModel.loadExercises()

        #expect(viewModel.exercises == expected)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }
}

private struct TestStrengthExerciseRepository:
    StrengthExerciseCatalogRepository {

    let exercises:
        [StrengthExerciseDefinition]

    func fetchExercises() async throws
        -> [StrengthExerciseDefinition] {
        exercises
    }
}
