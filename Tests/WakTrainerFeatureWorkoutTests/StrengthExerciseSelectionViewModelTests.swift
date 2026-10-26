import Testing
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@testable import WakTrainerFeatureWorkout

@MainActor
struct StrengthExerciseSelectionViewModelTests {

    @Test
    func localCatalogIncludesFullLowerBodyAndUniqueIdentifiers() async throws {
        let exercises = try await LocalStrengthExerciseCatalogRepository().fetchExercises()
        let identifiers = Set(exercises.map(\.id))
        #expect(exercises.count == 146)
        #expect(identifiers.count == exercises.count)
        for id in ["squat", "leg_press", "leg_extension", "seated_leg_curl",
                   "lying_leg_curl", "romanian_deadlift", "hip_thrust",
                   "calf_raise", "walking_lunge", "hip_abduction", "hip_adduction",
                   "smith_machine_squat", "pec_deck", "t_bar_row",
                   "arnold_press", "rope_triceps_pushdown", "pallof_press"] {
            #expect(identifiers.contains(id))
        }
    }

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
