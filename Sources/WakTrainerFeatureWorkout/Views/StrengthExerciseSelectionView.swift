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
        case .chest: return Set("chest_press incline_bench_press chest_fly push_up decline_bench_press close_grip_bench_press smith_machine_bench_press incline_machine_chest_press pec_deck incline_dumbbell_fly low_to_high_cable_fly high_to_low_cable_fly cable_chest_press dumbbell_floor_press chest_dip assisted_chest_dip decline_push_up incline_push_up diamond_push_up dumbbell_pullover bench_press".split(separator: " ").map(String.init)).contains(exercise.id)
        case .back: return Set("seated_cable_row pull_up assisted_pull_up single_arm_row wide_grip_lat_pulldown close_grip_lat_pulldown single_arm_lat_pulldown straight_arm_pulldown chest_supported_row t_bar_row landmine_row pendlay_row inverted_row machine_high_row single_arm_cable_row reverse_grip_row rack_pull back_extension weighted_back_extension shrug cable_shrug deadlift lat_pulldown barbell_row".split(separator: " ").map(String.init)).contains(exercise.id)
        case .shoulders: return Set("lateral_raise rear_delt_fly face_pull arnold_press seated_dumbbell_press machine_shoulder_press landmine_press front_raise cable_lateral_raise machine_lateral_raise lean_away_lateral_raise reverse_pec_deck bent_over_rear_delt_raise upright_row band_pull_apart external_rotation shoulder_press".split(separator: " ").map(String.init)).contains(exercise.id)
        case .arms: return Set("hammer_curl preacher_curl triceps_pushdown skull_crusher incline_dumbbell_curl concentration_curl spider_curl cable_biceps_curl reverse_curl zottman_curl bayesian_curl overhead_triceps_extension rope_triceps_pushdown single_arm_triceps_pushdown triceps_dip bench_dip triceps_kickback wrist_curl reverse_wrist_curl biceps_curl triceps_extension".split(separator: " ").map(String.init)).contains(exercise.id)
        case .legs: return Set("leg_press leg_extension seated_leg_curl lying_leg_curl romanian_deadlift bulgarian_split_squat walking_lunge hip_thrust calf_raise hack_squat goblet_squat smith_machine_squat front_squat sumo_squat box_squat split_squat reverse_lunge lateral_lunge step_up sissy_squat single_leg_press vertical_leg_press pendulum_squat belt_squat hip_abduction hip_adduction cable_kickback glute_bridge single_leg_glute_bridge nordic_curl standing_leg_curl single_leg_curl good_morning cable_pull_through single_leg_romanian_deadlift seated_calf_raise standing_calf_raise donkey_calf_raise tibialis_raise squat".split(separator: " ").map(String.init)).contains(exercise.id)
        case .core: return Set("cable_crunch hanging_leg_raise ab_wheel_rollout reverse_crunch bicycle_crunch dead_bug bird_dog russian_twist side_plank pallof_press woodchop decline_sit_up captains_chair_leg_raise hollow_body_hold mountain_climber kettlebell_swing turkish_get_up thruster clean_and_press burpee farmers_carry crunch plank".split(separator: " ").map(String.init)).contains(exercise.id)
        }
    }
}

@MainActor
struct StrengthExerciseSelectionView: View {
    @StateObject private var viewModel: StrengthExerciseSelectionViewModel
    @StateObject private var preferences = StrengthExerciseListPreferences()
    @State private var selectedGroup: StrengthMuscleGroup?
    @State private var selectedExercise: StrengthExerciseDefinition?
    @State private var searchText = ""

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
            .searchable(text: $searchText, prompt: "Search exercises")
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
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Favorites only", isOn: $preferences.favoritesOnly)
                    .font(.body)
                Picker("Sort by", selection: $preferences.sortMode) {
                    ForEach(StrengthExerciseListPreferences.SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .font(.body)
                if preferences.sortMode == .custom {
                    Text("Drag the handles to arrange your exercises")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.regularMaterial)
            Divider()
            List {
                ForEach(displayedExercises(for: group)) { exercise in
            Button {
                if exercise.supportedEquipment.count == 1,
                   let equipment = exercise.supportedEquipment.first {
                    select(exercise, equipment: equipment)
                } else {
                    selectedExercise = exercise
                }
            } label: {
                row(exercise.name)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button {
                    preferences.toggleFavorite(exercise.id)
                } label: {
                    Label(preferences.isFavorite(exercise.id) ? "Unfavorite" : "Favorite", systemImage: preferences.isFavorite(exercise.id) ? "star.slash" : "star")
                }
                .tint(.yellow)
            }
            }
                .onMove { from, to in
                    preferences.move(displayedExercises(for: group).map(\.id), from: from, to: to)
                }
            }
            .listStyle(.plain)
        }
        .environment(\.editMode, .constant(preferences.sortMode == .custom ? .active : .inactive))
        .listStyle(.plain)
    }

    private func equipmentList(for exercise: StrengthExerciseDefinition) -> some View {
        List(exercise.supportedEquipment, id: \.self) { equipment in
            Button {
                select(exercise, equipment: equipment)
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

    private func displayedExercises(for group: StrengthMuscleGroup) -> [StrengthExerciseDefinition] {
        preferences.ordered(viewModel.exercises.filter {
            group.contains($0) && (searchText.isEmpty || $0.name.localizedStandardContains(searchText))
        }, id: { $0.id }, name: { $0.name })
    }

    private func select(_ exercise: StrengthExerciseDefinition, equipment: StrengthEquipment) {
        preferences.recordSelection(exercise.id)
        onSelected(exercise, equipment)
    }

    private func row(_ name: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 54)
        .font(.title3.weight(.medium))
        .contentShape(Rectangle())
    }
}
