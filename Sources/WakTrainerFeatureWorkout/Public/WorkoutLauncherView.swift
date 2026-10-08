import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceWorkoutStorage

@MainActor
public struct WorkoutLauncherView: View {

    @StateObject private var viewModel:
        WorkoutLauncherViewModel

    private let weightUnit: WorkoutWeightUnit
    private let maximumHeartRate: Double?
    private let sessionRepository:
        (any WorkoutSessionRepository)?
    private let preferenceStore:
        any WorkoutLauncherPreferenceStore
    private let onFinished:
        (WorkoutSession) -> Void

    public init(
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        onFinished:
            @escaping (WorkoutSession) -> Void
    ) {
        let catalogRepository =
            LocalWorkoutCatalogRepository()
        let useCase =
            FetchWorkoutsUseCase(
                repository:
                    catalogRepository
            )
        let sessionRepository =
            try?
            SwiftDataWorkoutSessionRepository()
        let preferenceStore =
            UserDefaultsWorkoutLauncherPreferenceStore()

        self.maximumHeartRate =
            maximumHeartRate
        self.weightUnit = weightUnit
        self.sessionRepository =
            sessionRepository
        self.preferenceStore =
            preferenceStore
        self.onFinished =
            onFinished

        _viewModel = StateObject(
            wrappedValue:
                WorkoutLauncherViewModel(
                    fetchWorkoutsUseCase:
                        useCase,
                    sessionRepository:
                        sessionRepository,
                    preferenceStore:
                        preferenceStore
                )
        )
    }

    public var body: some View {
        VStack(spacing: 12) {
            if viewModel.isExpanded {
                launcherMenu
                    .transition(
                        .move(
                            edge: .bottom
                        )
                        .combined(
                            with: .opacity
                        )
                    )
            }

            orbButton
        }
        .animation(
            .spring(
                response: 0.3,
                dampingFraction: 0.8
            ),
            value:
                viewModel.isExpanded
        )
        .task {
            await viewModel.loadWorkouts()
            await viewModel
                .loadRecoverableWorkout()
        }
        .fullScreenCover(
            item:
                $viewModel.destination,
            onDismiss: {
                Task {
                    await viewModel
                        .loadWorkouts()
                }
            }
        ) { destination in
            workoutFlow(
                for: destination
            )
        }
        .confirmationDialog(
            "Resume Workout",
            isPresented:
                $viewModel
                    .isRecoveryPromptPresented,
            titleVisibility: .visible
        ) {
            Button("Resume") {
                viewModel
                    .openRecoverableWorkout()
            }

            Button(
                "Delete Saved Workout",
                role: .destructive
            ) {
                Task {
                    await viewModel
                        .discardRecoverableWorkout()
                }
            }

            Button(
                "Later",
                role: .cancel
            ) {
                viewModel
                    .dismissRecoveryPrompt()
            }
        } message: {
            if let stored =
                    viewModel
                        .recoverableSession {
                Text(
                    stored.session
                        .workout.name
                    + " · "
                    + formatDuration(
                        stored.session
                            .timing
                            .activeDuration
                    )
                )
            }
        }
        .alert(
            "Unable to Start Workout",
            isPresented: Binding(
                get: {
                    viewModel
                        .errorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        viewModel
                            .errorMessage = nil
                    }
                }
            )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                viewModel
                    .errorMessage = nil
            }
        } message: {
            Text(
                viewModel.errorMessage
                ?? ""
            )
        }
    }
}

private extension WorkoutLauncherView {

    var launcherMenu: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            if let stored =
                    viewModel
                        .recoverableSession {
                recoveryButton(
                    stored
                )
            }

            HStack {
                Text("Quick Start")
                    .font(.headline)

                Spacer()

                if viewModel
                    .isLoadingWorkouts {
                    ProgressView()
                        .controlSize(
                            .small
                        )
                }
            }

            if !viewModel
                .quickStartItems
                .isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: 10
                        ),
                        GridItem(
                            .flexible(),
                            spacing: 10
                        )
                    ],
                    spacing: 10
                ) {
                    ForEach(
                        viewModel
                            .quickStartItems
                    ) { item in
                        quickButton(
                            item: item
                        )
                    }
                }
            } else if !viewModel
                .isLoadingWorkouts {
                Text(
                    "No quick workouts available."
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
            }

            Button {
                viewModel.openCatalog()
            } label: {
                Label(
                    "Browse All Workouts",
                    systemImage:
                        "square.grid.2x2"
                )
                .font(.headline)
                .frame(
                    maxWidth: .infinity
                )
                .padding(
                    .vertical,
                    12
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .buttonBorderShape(
                .capsule
            )
        }
        .padding(14)
        .frame(maxWidth: 360)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }

    func recoveryButton(
        _ stored:
            StoredWorkoutSession
    ) -> some View {
        Button {
            viewModel
                .openRecoverableWorkout()
        } label: {
            HStack {
                Image(
                    systemName:
                        "arrow.clockwise.circle.fill"
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        "Resume Workout"
                    )
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        stored.session
                            .workout.name
                        + " · "
                        + formatDuration(
                            stored.session
                                .timing
                                .activeDuration
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(
                .vertical,
                8
            )
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(
            .roundedRectangle(
                radius: 16
            )
        )
    }

    var orbButton: some View {
        Button {
            viewModel
                .toggleLauncher()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        viewModel
                            .isExpanded
                            ? Color
                                .secondary
                                .opacity(
                                    0.18
                                )
                            : Color
                                .accentColor
                    )
                    .frame(
                        width: 64,
                        height: 64
                    )

                if viewModel
                    .isExpanded {
                    Image(
                        systemName:
                            "xmark"
                    )
                    .font(
                        .system(
                            size: 22,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )
                } else {
                    Text("W")
                        .font(
                            .system(
                                size: 24,
                                weight: .black,
                                design:
                                    .rounded
                            )
                        )
                        .foregroundStyle(
                            .white
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            viewModel.isExpanded
                ? "Close workout menu"
                : "Start workout"
        )
    }

    func quickButton(
        item: WorkoutQuickStartItem
    ) -> some View {
        Button {
            viewModel.openWorkout(
                item.workout
            )
        } label: {
            VStack(spacing: 6) {
                Image(
                    systemName:
                        item.workout
                            .launcherSystemImage
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )

                Text(
                    item.workout.name
                )
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 62
            )
            .padding(
                .horizontal,
                6
            )
            .overlay(
                alignment: .topTrailing
            ) {
                if item.source
                    == .favorite {
                    Image(
                        systemName:
                            "star.fill"
                    )
                    .font(.caption2)
                    .padding(6)
                }
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(
            .roundedRectangle(
                radius: 16
            )
        )
    }

    @ViewBuilder
    func workoutFlow(
        for destination:
            WorkoutLauncherViewModel
                .Destination
    ) -> some View {
        switch destination {
        case .workout(
            let workout
        ):
            WorkoutFeatureView(
                initialWorkout:
                    workout,
                sessionRepository:
                    sessionRepository,
                preferenceStore:
                    preferenceStore,
                maximumHeartRate:
                    maximumHeartRate,
                weightUnit: weightUnit,
                onCancelled: {
                    viewModel
                        .dismissWorkoutFlow()
                },
                onFinished: {
                    session in
                    viewModel
                        .dismissWorkoutFlow()
                    onFinished(
                        session
                    )
                }
            )

        case .catalog:
            WorkoutFeatureView(
                initialWorkout: nil,
                initialCategory:
                    .strength,
                sessionRepository:
                    sessionRepository,
                preferenceStore:
                    preferenceStore,
                maximumHeartRate:
                    maximumHeartRate,
                weightUnit: weightUnit,
                onCancelled: {
                    viewModel
                        .dismissWorkoutFlow()
                },
                onFinished: {
                    session in
                    viewModel
                        .dismissWorkoutFlow()
                    onFinished(
                        session
                    )
                }
            )

        case .recovered(
            let workout,
            let storedSession
        ):
            WorkoutFeatureView(
                initialWorkout:
                    workout,
                restoredSession:
                    storedSession,
                sessionRepository:
                    sessionRepository,
                preferenceStore:
                    preferenceStore,
                maximumHeartRate:
                    maximumHeartRate,
                weightUnit: weightUnit,
                onCancelled: {
                    viewModel
                        .dismissWorkoutFlow()
                },
                onFinished: {
                    session in
                    viewModel
                        .dismissWorkoutFlow()
                    onFinished(
                        session
                    )
                }
            )
        }
    }

    func formatDuration(
        _ duration: TimeInterval
    ) -> String {
        let totalSeconds =
            max(
                0,
                Int(duration)
            )
        let hours =
            totalSeconds / 3_600
        let minutes =
            (totalSeconds % 3_600)
            / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}
