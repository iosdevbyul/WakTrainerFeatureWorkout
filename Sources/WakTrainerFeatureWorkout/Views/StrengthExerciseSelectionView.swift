import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@MainActor
struct StrengthExerciseSelectionView:
    View {

    @StateObject private var viewModel:
        StrengthExerciseSelectionViewModel
    @State private var selectedExercise:
        StrengthExerciseDefinition?

    private let onCancel: () -> Void
    private let onSelected:
        (
            StrengthExerciseDefinition,
            StrengthEquipment
        ) -> Void

    init(
        fetchExercisesUseCase:
            FetchStrengthExercisesUseCase,
        onCancel:
            @escaping () -> Void,
        onSelected:
            @escaping (
                StrengthExerciseDefinition,
                StrengthEquipment
            ) -> Void
    ) {
        self.onCancel = onCancel
        self.onSelected = onSelected

        _viewModel = StateObject(
            wrappedValue:
                StrengthExerciseSelectionViewModel(
                    fetchExercisesUseCase:
                        fetchExercisesUseCase
                )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedExercise {
                    equipmentList(
                        for: selectedExercise
                    )
                } else {
                    exerciseContent
                }
            }
            .navigationTitle(
                selectedExercise?.name
                    ?? "Choose Exercise"
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    if selectedExercise != nil {
                        Button("Back") {
                            self.selectedExercise = nil
                        }
                    } else {
                        Button("Close") {
                            onCancel()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel
                .loadExercises()
        }
    }

    @ViewBuilder
    private var exerciseContent:
        some View {
        if viewModel.isLoading {
            ProgressView(
                "Loading exercises..."
            )
        } else if let errorMessage =
                    viewModel.errorMessage {
            ContentUnavailableView {
                Label(
                    "Unable to Load Exercises",
                    systemImage:
                        "exclamationmark.triangle"
                )
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task {
                        await viewModel
                            .loadExercises()
                    }
                }
            }
        } else {
            List(
                viewModel.exercises
            ) { exercise in
                Button {
                    selectedExercise =
                        exercise
                } label: {
                    HStack {
                        Text(exercise.name)
                            .foregroundStyle(
                                .primary
                            )

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func equipmentList(
        for exercise:
            StrengthExerciseDefinition
    ) -> some View {
        List(
            exercise.supportedEquipment,
            id: \.self
        ) { equipment in
            Button {
                onSelected(
                    exercise,
                    equipment
                )
            } label: {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(
                            equipment.displayName
                        )
                        .foregroundStyle(
                            .primary
                        )

                        Text(
                            equipment
                                .requiresWeightInput
                                ? "Weight and reps"
                                : "Reps"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            "checkmark.circle"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}
