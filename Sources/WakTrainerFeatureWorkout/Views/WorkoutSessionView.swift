import SwiftUI
import MapKit
import WakTrainerFeatureTimer
import WakTrainerServiceLocation
import WakTrainerCoreModels

public struct WorkoutSessionView: View {
    @StateObject private var viewModel: FitnessViewModel
    
    // 운동 타입 (예: 동적 운동 / 정적 운동)
    private let workoutType: WorkoutType

    public init(
        viewModel: FitnessViewModel = FitnessViewModel(),
        workoutType: WorkoutType = .dynamicWorkout
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.workoutType = workoutType
    }

    public var body: some View {
        ZStack {
            // 1. 배경: GPS 지도 영역 (하위 모듈 WorkoutMapView 활용)
            WorkoutMapView(
                workoutType: workoutType,
                paceSegments: currentPaceSegments
            )
            .ignoresSafeArea()

            // 2. 전면 Overlay 레이아웃
            VStack {
                // 상단: 타이머 캡슐 컴포넌트 (하위 모듈 CapsuleTimerView 활용)
                HStack {
                    CapsuleTimerView(
                        timerManager: viewModel.timerManager,
                        textColor: .black
                    )
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                Spacer()

                // 하단: 운동 데이터 트래킹 및 제어 영역
                VStack(spacing: 16) {
                    // 수치 카드 리스트 (HealthKit + Location 데이터)
                    WorkoutTrackerView(viewModel: viewModel)

                    // 운동 제어 버튼 그룹
                    controlButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 12) {
            if viewModel.timerState == .idle {
                Button(action: {
                    Task {
                        await viewModel.startWorkout()
                    }
                }) {
                    Text("운동 시작")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            } else {
                // 일시정지 / 재개 버튼
                Button(action: {
                    if viewModel.timerState == .running {
                        viewModel.pauseWorkout()
                    } else {
                        viewModel.resumeWorkout()
                    }
                }) {
                    Text(viewModel.timerState == .running ? "일시정지" : "재개")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.timerState == .running ? Color.orange : Color.green)
                        .cornerRadius(14)
                }

                // 종료 버튼
                Button(action: {
                    viewModel.stopWorkout()
                }) {
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

    // MARK: - Map Helper
    /// 실시간 좌표 데이터를 WorkoutMapView용 PaceSegment로 간단히 변환
    private var currentPaceSegments: [PaceSegment] {
        let coords = viewModel.routeCoordinates
        guard coords.count >= 2 else { return [] }
        
        var segments: [PaceSegment] = []
        for i in 0..<(coords.count - 1) {
            let segment = PaceSegment(
                startCoordinate: coords[i],
                endCoordinate: coords[i + 1],
                speedCategory: .moderate, // 실시간 평균 속도 연산 logic 추가 가능
                speedMs: 2.5
            )
            segments.append(segment)
        }
        return segments
    }
}
