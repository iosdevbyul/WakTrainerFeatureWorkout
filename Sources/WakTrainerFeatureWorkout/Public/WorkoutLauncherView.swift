import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceWorkoutStorage

@MainActor
public struct WorkoutLauncherView: View {

    @StateObject private var viewModel: WorkoutLauncherViewModel

    private let maximumHeartRate: Double?
    private let sessionRepository:
        (any WorkoutSessionRepository)?
    private let onFinished: (WorkoutSession) -> Void

    public init(
        maximumHeartRate: Double? = nil,
        onFinished: @escaping (WorkoutSession) -> Void
    ) {
        let catalogRepository =
            LocalWorkoutCatalogRepository()
        let useCase = FetchWorkoutsUseCase(
            repository: catalogRepository
        )
        let sessionRepository =
            try? SwiftDataWorkoutSessionRepository()

        self.maximumHeartRate = maximumHeartRate
        self.sessionRepository = sessionRepository
        self.onFinished = onFinished

        _viewModel = StateObject(
            wrappedValue: WorkoutLauncherViewModel(
                fetchWorkoutsUseCase: useCase,
                sessionRepository: sessionRepository
            )
        )
    }

    public var body: some View {
        VStack(spacing: 12) {
            if viewModel.isExpanded {
                launcherMenu
                    .transition(
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                    )
            }

            orbButton
        }
        .animation(
            .spring(
                response: 0.3,
                dampingFraction: 0.8
            ),
            value: viewModel.isExpanded
        )
        .animation(
            .spring(
                response: 0.3,
                dampingFraction: 0.8
            ),
            value: viewModel.isCyclingExpanded
        )
        .task {
            await viewModel.loadRecoverableWorkout()
        }
        .fullScreenCover(
            item: $viewModel.destination
        ) { destination in
            workoutFlow(
                for: destination
            )
        }
        .confirmationDialog(
            "이전 운동 기록이 있습니다",
            isPresented:
                $viewModel.isRecoveryPromptPresented,
            titleVisibility: .visible
        ) {
            Button("이전 운동 이어하기") {
                viewModel.openRecoverableWorkout()
            }

            Button(
                "저장된 운동 삭제",
                role: .destructive
            ) {
                Task {
                    await viewModel
                        .discardRecoverableWorkout()
                }
            }

            Button(
                "나중에",
                role: .cancel
            ) {
                viewModel.dismissRecoveryPrompt()
            }
        } message: {
            if let stored =
                    viewModel.recoverableSession {
                Text(
                    "\(stored.session.workout.name) · " +
                    formatDuration(
                        stored.session
                            .timing.activeDuration
                    )
                )
            }
        }
        .alert(
            "운동을 시작할 수 없습니다",
            isPresented: Binding(
                get: {
                    viewModel.errorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(
                viewModel.errorMessage ?? ""
            )
        }
    }
}

private extension WorkoutLauncherView {

    var launcherMenu: some View {
        VStack(spacing: 10) {
            if let stored =
                    viewModel.recoverableSession {
                Button {
                    viewModel.openRecoverableWorkout()
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
                            Text("이전 운동 이어하기")
                                .fontWeight(.semibold)

                            Text(
                                stored.session.workout.name +
                                " · " +
                                formatDuration(
                                    stored.session
                                        .timing.activeDuration
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(
                    .roundedRectangle(
                        radius: 16
                    )
                )
            }

            HStack(spacing: 10) {
                quickButton(
                    title: "러닝",
                    systemImage: "figure.run"
                ) {
                    Task {
                        await viewModel.openWorkout(
                            .running
                        )
                    }
                }

                quickButton(
                    title: "걷기",
                    systemImage: "figure.walk"
                ) {
                    Task {
                        await viewModel.openWorkout(
                            .walking
                        )
                    }
                }

                quickButton(
                    title: "자전거",
                    systemImage: "bicycle"
                ) {
                    viewModel.toggleCyclingOptions()
                }
            }

            if viewModel.isCyclingExpanded {
                HStack(spacing: 10) {
                    quickButton(
                        title: "실내",
                        systemImage: "bicycle.circle"
                    ) {
                        Task {
                            await viewModel.openWorkout(
                                .indoorCycling
                            )
                        }
                    }

                    quickButton(
                        title: "야외",
                        systemImage: "map"
                    ) {
                        Task {
                            await viewModel.openWorkout(
                                .outdoorCycling
                            )
                        }
                    }
                }
                .transition(
                    .move(edge: .bottom)
                    .combined(with: .opacity)
                )
            }

            Button {
                viewModel.openStrengthSelection()
            } label: {
                Label(
                    "근력운동",
                    systemImage: "dumbbell.fill"
                )
                .font(.headline)
                .frame(
                    maxWidth: .infinity
                )
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
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

    var orbButton: some View {
        Button {
            viewModel.toggleLauncher()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        viewModel.isExpanded
                            ? Color.secondary.opacity(0.18)
                            : Color.accentColor
                    )
                    .frame(
                        width: 64,
                        height: 64
                    )

                if viewModel.isExpanded {
                    Image(
                        systemName: "xmark"
                    )
                    .font(
                        .system(
                            size: 22,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.primary)
                } else {
                    Text("W")
                        .font(
                            .system(
                                size: 24,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            viewModel.isExpanded
                ? "운동 메뉴 닫기"
                : "운동 시작"
        )
    }

    func quickButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            VStack(spacing: 6) {
                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(
                minWidth: 78,
                minHeight: 62
            )
            .padding(.horizontal, 6)
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
        for destination: WorkoutLauncherViewModel.Destination
    ) -> some View {
        switch destination {
        case .workout(let workout):
            WorkoutFeatureView(
                initialWorkout: workout,
                sessionRepository: sessionRepository,
                maximumHeartRate: maximumHeartRate,
                onCancelled: {
                    viewModel.dismissWorkoutFlow()
                },
                onFinished: { session in
                    viewModel.dismissWorkoutFlow()
                    onFinished(session)
                }
            )

        case .category(let category):
            WorkoutFeatureView(
                initialWorkout: nil,
                initialCategory: category,
                sessionRepository: sessionRepository,
                maximumHeartRate: maximumHeartRate,
                onCancelled: {
                    viewModel.dismissWorkoutFlow()
                },
                onFinished: { session in
                    viewModel.dismissWorkoutFlow()
                    onFinished(session)
                }
            )

        case .recovered(
            let workout,
            let storedSession
        ):
            WorkoutFeatureView(
                initialWorkout: workout,
                restoredSession: storedSession,
                sessionRepository: sessionRepository,
                maximumHeartRate: maximumHeartRate,
                onCancelled: {
                    viewModel.dismissWorkoutFlow()
                },
                onFinished: { session in
                    viewModel.dismissWorkoutFlow()
                    onFinished(session)
                }
            )
        }
    }

    func formatDuration(
        _ duration: TimeInterval
    ) -> String {
        let totalSeconds = max(
            0,
            Int(duration)
        )
        let hours = totalSeconds / 3_600
        let minutes =
            (totalSeconds % 3_600) / 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }

        return "\(minutes)분"
    }
}
