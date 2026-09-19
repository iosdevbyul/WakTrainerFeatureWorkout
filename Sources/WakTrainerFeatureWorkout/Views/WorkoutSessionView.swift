import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer
import WakTrainerServiceLocation

public struct WorkoutSessionView: View {
    @StateObject private var viewModel: WorkoutSessionViewModel

    private let workout: WorkoutDefinition
    private let onFinished: (WorkoutFeatureResult) -> Void
    
    public init(
        workout: WorkoutDefinition,
        onFinished: @escaping (WorkoutFeatureResult) -> Void
    ) {
        self.workout = workout
        self.onFinished = onFinished

        _viewModel = StateObject(
            wrappedValue: WorkoutSessionViewModel(
                workout: workout
            )
        )
    }

    public var body: some View {
        ZStack {
            sessionBackground

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)

                        CapsuleTimerView(
                            timerManager: viewModel.timerManager,
                            textColor: .black
                        )
                    }

                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 16) {
                    WorkoutTrackerView(
                        viewModel: viewModel
                    )

                    controlButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var sessionBackground: some View {
        if workout.requiresLocationTracking {
            WorkoutMapView(
                workoutType: workout.type,
                paceSegments: currentPaceSegments
            )
            .ignoresSafeArea()
        } else {
            Color.clear
                .ignoresSafeArea()
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 12) {
            if viewModel.timerState == .idle {
                Button {
                    Task {
                        await viewModel.startWorkout()
                    }
                } label: {
                    Text("운동 시작")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            } else {
                Button {
                    if viewModel.timerState == .running {
                        viewModel.pauseWorkout()
                    } else {
                        viewModel.resumeWorkout()
                    }
                } label: {
                    Text(
                        viewModel.timerState == .running
                        ? "일시정지"
                        : "재개"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        viewModel.timerState == .running
                        ? Color.orange
                        : Color.green
                    )
                    .cornerRadius(14)
                }

                Button {
                    let result = viewModel.makeResult()
                    viewModel.stopWorkout()
                    onFinished(result)
                } label: {
                    Text("운동 종료")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(14)
                }
            }
        }
    }

    // MARK: - Route

    private var currentPaceSegments: [PaceSegment] {
        let coordinates = viewModel.routeCoordinates

        guard coordinates.count >= 2 else {
            return []
        }

        return (0..<(coordinates.count - 1)).map { index in
            PaceSegment(
                startCoordinate: coordinates[index],
                endCoordinate: coordinates[index + 1],
                speedCategory: .moderate,
                speedMs: 2.5
            )
        }
    }
}
