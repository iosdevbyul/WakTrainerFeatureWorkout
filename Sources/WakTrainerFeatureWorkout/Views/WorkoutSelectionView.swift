
import SwiftUI
import WakTrainerDomainWorkout

public struct WorkoutSelectionView: View {

    @StateObject private var viewModel: WorkoutSelectionViewModel

    private let onWorkoutSelected: (WorkoutDefinition) -> Void

    init(
        fetchWorkoutsUseCase: FetchWorkoutsUseCase,
        onWorkoutSelected: @escaping (WorkoutDefinition) -> Void
    ) {
        self.onWorkoutSelected = onWorkoutSelected

        _viewModel = StateObject(
            wrappedValue: WorkoutSelectionViewModel(
                fetchWorkoutsUseCase: fetchWorkoutsUseCase
            )
        )
    }

    public var body: some View {
        VStack(spacing: 20) {
            categoryPicker

            content
        }
        .padding(.horizontal, 20)
        .navigationTitle("운동 선택")
        .task {
            await viewModel.loadWorkouts()
        }
    }

    // MARK: - Category

    private var categoryPicker: some View {
        Picker(
            "운동 종류",
            selection: $viewModel.selectedCategory
        ) {
            ForEach(WorkoutCategory.allCases, id: \.self) { category in
                Text(category.title)
                    .tag(category)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingView
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.filteredWorkouts.isEmpty {
            emptyView
        } else {
            workoutList
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()

            ProgressView("운동 목록 불러오는 중")

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(
        message: String
    ) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text("운동 목록을 불러오지 못했습니다.")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task {
                    await viewModel.loadWorkouts()
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack {
            Spacer()

            Text("등록된 운동이 없습니다.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var workoutList: some View {
        List(viewModel.filteredWorkouts) { workout in
            Button {
                onWorkoutSelected(workout)
            } label: {
                WorkoutSelectionRow(
                    workout: workout
                )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}

// MARK: - WorkoutSelectionRow

private struct WorkoutSelectionRow: View {

    let workout: WorkoutDefinition

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name)
                    .font(.headline)

                Text(workout.trackingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: workout.trackingIcon)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Presentation

private extension WorkoutCategory {

    var title: String {
        switch self {
        case .strength:
            "근력"

        case .cardio:
            "유산소"
        }
    }
}

private extension WorkoutDefinition {

    var trackingDescription: String {
        requiresLocationTracking
            ? "이동 경로 기록"
            : "위치 기록 없음"
    }

    var trackingIcon: String {
        requiresLocationTracking
            ? "location.fill"
            : "location.slash"
    }
}
