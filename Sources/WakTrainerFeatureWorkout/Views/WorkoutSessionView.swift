import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer
import WakTrainerServiceLocation
import WakTrainerServiceWorkoutStorage

@MainActor
struct WorkoutSessionView: View {

    @StateObject private var viewModel:
        WorkoutSessionViewModel
    @State private var isExercisePickerPresented =
        false
    @State private var didPresentInitialExercisePicker = false

    private let workout:
        WorkoutDefinition
    private let fetchStrengthExercisesUseCase:
        FetchStrengthExercisesUseCase
    private let onCancel: () -> Void
    private let onFinished:
        (WorkoutSession) -> Void

    init(
        workout: WorkoutDefinition,
        restoredSession:
            StoredWorkoutSession? = nil,
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        onCancel:
            @escaping () -> Void,
        onFinished:
            @escaping (WorkoutSession) -> Void
    ) {
        self.workout = workout
        self.onCancel = onCancel
        self.onFinished = onFinished

        let resolvedRepository =
            sessionRepository
            ?? (
                try?
                SwiftDataWorkoutSessionRepository()
            )

        let strengthRepository =
            LocalStrengthExerciseCatalogRepository()

        self.fetchStrengthExercisesUseCase =
            FetchStrengthExercisesUseCase(
                repository:
                    strengthRepository
            )

        _viewModel = StateObject(
            wrappedValue:
                WorkoutSessionViewModel(
                    workout: workout,
                    restoredSession:
                        restoredSession,
                    sessionRepository:
                        resolvedRepository
                )
        )
    }

    var body: some View {
        ZStack {
            sessionBackground

            if workout.category
                == .strength {
                strengthSessionContent
            } else {
                cardioSessionContent
            }
        }
        .toolbar {
            if viewModel.timerState
                == .idle {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button("Back") {
                        onCancel()
                    }
                }
            }
        }
        .onAppear {
            guard workout.category == .strength,
                  viewModel.timerState == .idle,
                  viewModel.activeStrengthExercise == nil,
                  !didPresentInitialExercisePicker else { return }
            didPresentInitialExercisePicker = true
            isExercisePickerPresented = true
        }
        .sheet(
            isPresented:
                $isExercisePickerPresented
        ) {
            StrengthExerciseSelectionView(
                fetchExercisesUseCase:
                    fetchStrengthExercisesUseCase,
                onCancel: {
                    isExercisePickerPresented =
                        false
                },
                onSelected: {
                    exercise,
                    equipment in

                    let didSelect = viewModel.beginStrengthExercise(
                        exercise,
                        equipment: equipment
                    )
                    isExercisePickerPresented = false
                    if didSelect && viewModel.timerState == .idle {
                        Task { await viewModel.startWorkout() }
                    }
                }
            )
        }
    }

    // MARK: - Shared Header

    private var header:
        some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(workout.name)
                    .font(.headline)

                CapsuleTimerView(
                    timerManager:
                        viewModel
                            .timerManager,
                    textColor: .black
                )
            }

            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Cardio

    private var cardioSessionContent:
        some View {
        VStack {
            header

            Spacer()

            VStack(spacing: 16) {
                WorkoutTrackerView(
                    viewModel:
                        viewModel
                )

                controlButtons
            }
            .padding(
                .horizontal,
                20
            )
            .padding(
                .bottom,
                24
            )
        }
    }

    // MARK: - Strength

    private var strengthSessionContent:
        some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel
                        .completedStrengthExerciseRecords
                        .isEmpty {
                        completedExercisesCard
                    }

                    if let activeExercise =
                            viewModel
                                .activeStrengthExercise {
                        activeExerciseCard(
                            activeExercise
                        )
                    } else {
                        chooseExerciseCard
                    }

                    if viewModel.timerState
                        != .idle,
                       viewModel
                        .activeStrengthExercise
                        != nil,
                       viewModel
                        .activeStrengthEquipment
                        != nil {
                        StrengthSetRecorderView(
                            viewModel:
                                viewModel
                        )
                    }

                    WorkoutTrackerView(
                        viewModel:
                            viewModel
                    )

                    if viewModel.timerState
                        != .idle {
                        Button {
                            isExercisePickerPresented =
                                true
                        } label: {
                            Label(
                                "Add Exercise",
                                systemImage:
                                    "plus.circle.fill"
                            )
                            .font(.headline)
                            .frame(
                                maxWidth:
                                    .infinity
                            )
                            .padding(
                                .vertical,
                                12
                            )
                        }
                        .buttonStyle(
                            .bordered
                        )
                        .buttonBorderShape(
                            .roundedRectangle(
                                radius: 16
                            )
                        )
                    }

                    controlButtons
                }
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .top,
                    20
                )
                .padding(
                    .bottom,
                    24
                )
            }
        }
    }

    private var chooseExerciseCard:
        some View {
        Button {
            isExercisePickerPresented =
                true
        } label: {
            VStack(spacing: 10) {
                Image(
                    systemName:
                        "figure.strengthtraining.traditional"
                )
                .font(
                    .system(
                        size: 28,
                        weight: .semibold
                    )
                )

                Text(
                    "Choose Exercise"
                )
                .font(.headline)

                Text(
                    "Select an exercise and equipment to begin."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                maxWidth: .infinity
            )
            .padding(20)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(
            .roundedRectangle(
                radius: 18
            )
        )
    }

    private func activeExerciseCard(
        _ exercise:
            StrengthExerciseDefinition
    ) -> some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(exercise.name)
                    .font(.headline)

                if let equipment =
                        viewModel
                            .activeStrengthEquipment {
                    Text(
                        equipment
                            .displayName
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                } else {
                    Text(
                        "Choose Equipment"
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                }

                if !viewModel
                    .strengthSets
                    .isEmpty {
                    Text(
                        "\(viewModel.strengthSets.count) completed sets"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Button(
                viewModel.timerState
                    == .idle
                    ? "Change"
                    : "Switch"
            ) {
                isExercisePickerPresented =
                    true
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var completedExercisesCard:
        some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Completed Exercises")
                .font(.headline)

            ForEach(
                viewModel
                    .completedStrengthExerciseRecords
            ) { record in
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(record.name)
                            .font(
                                .subheadline
                            )
                            .fontWeight(
                                .semibold
                            )

                        HStack(spacing: 6) {
                            if let equipment =
                                    record
                                        .strengthEquipment {
                                Text(
                                    equipment
                                        .displayName
                                )
                            }

                            Text(
                                "\(record.strengthSets.count) sets"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var sessionBackground:
        some View {
        if workout
            .requiresLocationTracking {
            WorkoutMapView(
                workoutType:
                    workout.type,
                paceSegments:
                    currentPaceSegments
            )
            .ignoresSafeArea()
        } else {
            Color.clear
                .ignoresSafeArea()
        }
    }

    // MARK: - Controls

    private var controlButtons:
        some View {
        HStack(spacing: 12) {
            if viewModel.timerState
                == .idle {
                Button {
                    Task {
                        await viewModel
                            .startWorkout()
                    }
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(
                            .white
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .padding()
                        .background(
                            viewModel
                                .canStartWorkout
                            ? Color.blue
                            : Color.gray
                        )
                        .cornerRadius(14)
                }
                .disabled(
                    !viewModel
                        .canStartWorkout
                )
            } else {
                Button {
                    if viewModel.timerState
                        == .running {
                        viewModel
                            .pauseWorkout()
                    } else {
                        viewModel
                            .resumeWorkout()
                    }
                } label: {
                    Text(
                        viewModel
                            .timerState
                            == .running
                        ? "Pause"
                        : "Resume"
                    )
                    .font(.headline)
                    .foregroundColor(
                        .white
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding()
                    .background(
                        viewModel
                            .timerState
                            == .running
                        ? Color.orange
                        : Color.green
                    )
                    .cornerRadius(14)
                }

                Button {
                    Task {
                        let session =
                            await viewModel
                                .finishWorkout()
                        onFinished(
                            session
                        )
                    }
                } label: {
                    Text(
                        "Finish Workout"
                    )
                    .font(.headline)
                    .foregroundColor(
                        .white
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding()
                    .background(
                        Color.red
                    )
                    .cornerRadius(14)
                }
            }
        }
    }

    // MARK: - Route

    private var currentPaceSegments:
        [PaceSegment] {
        let coordinates =
            viewModel
                .routeCoordinates

        guard coordinates.count
            >= 2 else {
            return []
        }

        return (
            0..<(coordinates.count - 1)
        ).map { index in
            PaceSegment(
                startCoordinate:
                    coordinates[index],
                endCoordinate:
                    coordinates[
                        index + 1
                    ],
                speedCategory:
                    .moderate,
                speedMs: 2.5
            )
        }
    }
}
