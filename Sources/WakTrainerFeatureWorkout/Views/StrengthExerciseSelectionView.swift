import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout

/// Local navigation metadata. Exercise IDs remain the stable persisted identifiers.
enum StrengthMuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"

    var id: String { rawValue }

    func contains(_ exercise: StrengthExerciseDefinition) -> Bool {
        switch self {
        case .chest: return ["bench_press"].contains(exercise.id)
        case .back: return ["deadlift", "lat_pulldown", "barbell_row"].contains(exercise.id)
        case .shoulders: return ["shoulder_press"].contains(exercise.id)
        case .arms: return ["biceps_curl", "triceps_extension"].contains(exercise.id)
        case .legs: return ["squat"].contains(exercise.id)
        case .core: return ["crunch", "plank"].contains(exercise.id)
        }
    }
}

@MainActor
struct StrengthExerciseSelectionView: View {
    @StateObject private var viewModel: StrengthExerciseSelectionViewModel
    @State private var selectedGroup: StrengthMuscleGroup?
    @State private var selectedExercise: StrengthExerciseDefinition?

    private let onCancel: () -> Void
    private let onSelected: (StrengthExerciseDefinition, StrengthEquipment) -> Void

    init(
        fetchExercisesUseCase: FetchStrengthExercisesUseCase,
        onCancel: @escaping () -> Void,
        onSelected: @escaping (StrengthExerciseDefinition, StrengthEquipment) -> Void
    ) {
        self.onCancel = onCancel
        self.onSelected = onSelected
        _viewModel = StateObject(
            wrappedValue: StrengthExerciseSelectionViewModel(
                fetchExercisesUseCase: fetchExercisesUseCase
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedExercise {
                    equipmentList(for: selectedExercise)
                } else if let selectedGroup {
                    exerciseList(for: selectedGroup)
                } else {
                    muscleGroups
                }
            }
            .navigationTitle(selectedExercise?.name ?? selectedGroup?.rawValue ?? "Choose Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedExercise != nil {
                        Button("Back") { selectedExercise = nil }
                    } else if selectedGroup != nil {
                        Button("Back") { selectedGroup = nil }
                    } else {
                        Button("Close", action: onCancel)
                    }
                }
            }
        }
        .task { await viewModel.loadExercises() }
    }

    @ViewBuilder
    private var muscleGroups: some View {
        if viewModel.isLoading {
            ProgressView("Loading exercises...")
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Unable to Load Exercises", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadExercises() }
                }
            }
        } else {
            List(StrengthMuscleGroup.allCases) { group in
                Button {
                    selectedGroup = group
                } label: {
                    row(group.rawValue)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func exerciseList(for group: StrengthMuscleGroup) -> some View {
        List(viewModel.exercises.filter { group.contains($0) }) { exercise in
            Button {
                if exercise.supportedEquipment.count == 1,
                   let equipment = exercise.supportedEquipment.first {
                    onSelected(exercise, equipment)
                } else {
                    selectedExercise = exercise
                }
            } label: {
                row(exercise.name)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private func equipmentList(for exercise: StrengthExerciseDefinition) -> some View {
        List(exercise.supportedEquipment, id: \.self) { equipment in
            Button {
                onSelected(exercise, equipment)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(equipment.displayName)
                            .foregroundStyle(.primary)
                        Text(equipment.requiresWeightInput ? "Weight and reps" : "Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private func row(_ name: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
