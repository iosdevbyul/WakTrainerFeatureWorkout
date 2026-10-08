import SwiftUI
import WakTrainerDomainWorkout

struct WorkoutSelectionView: View {

    @StateObject private var viewModel:
        WorkoutSelectionViewModel

    private let onWorkoutSelected:
        (WorkoutDefinition) -> Void
    private let onCancel:
        (() -> Void)?

    init(
        fetchWorkoutsUseCase:
            FetchWorkoutsUseCase,
        initialCategory:
            WorkoutCategory = .strength,
        preferenceStore:
            any WorkoutLauncherPreferenceStore =
                UserDefaultsWorkoutLauncherPreferenceStore(),
        onCancel:
            (() -> Void)? = nil,
        onWorkoutSelected:
            @escaping (WorkoutDefinition) -> Void
    ) {
        self.onWorkoutSelected =
            onWorkoutSelected
        self.onCancel =
            onCancel

        _viewModel = StateObject(
            wrappedValue:
                WorkoutSelectionViewModel(
                    fetchWorkoutsUseCase:
                        fetchWorkoutsUseCase,
                    initialCategory:
                        initialCategory,
                    preferenceStore:
                        preferenceStore
                )
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            categoryPicker

            content
        }
        .padding(.horizontal, 20)
        .navigationTitle(
            "Choose Workout"
        )
        .toolbar {
            if let onCancel {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button("Close") {
                        onCancel()
                    }
                }
            }
        }
        .task {
            await viewModel
                .loadWorkouts()
        }
    }

    private var categoryPicker:
        some View {
        Picker(
            "Workout Type",
            selection:
                $viewModel
                    .selectedCategory
        ) {
            ForEach(
                WorkoutCategory
                    .allCases,
                id: \.self
            ) { category in
                Text(category.title)
                    .tag(category)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content:
        some View {
        if viewModel.isLoading {
            loadingView
        } else if let errorMessage =
                    viewModel
                        .errorMessage {
            errorView(
                message:
                    errorMessage
            )
        } else if viewModel
            .filteredWorkouts
            .isEmpty {
            emptyView
        } else {
            workoutList
        }
    }

    private var loadingView:
        some View {
        VStack {
            Spacer()

            ProgressView(
                "Loading workouts..."
            )

            Spacer()
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private func errorView(
        message: String
    ) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text(
                "Unable to Load Workouts"
            )
            .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )

            Button("Try Again") {
                Task {
                    await viewModel
                        .loadWorkouts()
                }
            }

            Spacer()
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private var emptyView:
        some View {
        VStack {
            Spacer()

            Text(
                "No workouts available."
            )
            .foregroundStyle(
                .secondary
            )

            Spacer()
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private var workoutList:
        some View {
        List(
            viewModel
                .filteredWorkouts
        ) { workout in
            HStack(spacing: 12) {
                Button {
                    onWorkoutSelected(
                        workout
                    )
                } label: {
                    WorkoutSelectionRow(
                        workout:
                            workout
                    )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel
                        .toggleFavorite(
                            workout
                        )
                } label: {
                    Image(
                        systemName:
                            viewModel
                                .isFavorite(
                                    workout
                                )
                            ? "star.fill"
                            : "star"
                    )
                    .font(.headline)
                    .frame(
                        width: 36,
                        height: 36
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    viewModel
                        .isFavorite(
                            workout
                        )
                    ? "Remove from Favorites"
                    : "Add to Favorites"
                )
            }
        }
        .listStyle(.plain)
    }
}

private struct WorkoutSelectionRow:
    View {

    let workout:
        WorkoutDefinition

    var body: some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(workout.name)
                    .font(.headline)

                Text(
                    workout
                        .trackingDescription
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Image(
                systemName:
                    workout
                        .trackingIcon
            )
            .foregroundStyle(
                .secondary
            )
        }
        .contentShape(
            Rectangle()
        )
        .padding(
            .vertical,
            6
        )
    }
}

private extension WorkoutCategory {

    var title: String {
        switch self {
        case .strength:
            "Strength"

        case .cardio:
            "Cardio"
        }
    }
}

private extension WorkoutDefinition {

    var trackingDescription:
        String {
        requiresLocationTracking
            ? "Route tracking"
            : "No route tracking"
    }

    var trackingIcon: String {
        requiresLocationTracking
            ? "location.fill"
            : "location.slash"
    }
}
