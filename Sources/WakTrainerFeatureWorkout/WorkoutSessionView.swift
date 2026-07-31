//
//  WorkoutSessionView.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-07-31.
//

import SwiftUI
import WakTrainerCoreModels

public struct WorkoutSessionView: View {
    @StateObject private var viewModel: WorkoutSessionViewModel

    // 외부에서 ViewModel을 주입받을 수 있도록 의존성 주입(DI) 지원
    public init(viewModel: WorkoutSessionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // 기본 생성자: 내부에서 MainActor 격리 상태로 ViewModel 생성
    public init() {
        _viewModel = StateObject(wrappedValue: WorkoutSessionViewModel())
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text("Workout Session")
                .font(.largeTitle)
                .bold()

            TextField("Workout Name (e.g. Bench Press)", text: $viewModel.selectedWorkoutTitle)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Text("Elapsed Time: \(formattedTime(viewModel.elapsedTime))")
                .font(.title2)
                .monospacedDigit()

            HStack(spacing: 16) {
                if viewModel.isRunning {
                    Button(action: {
                        viewModel.stopSession()
                    }) {
                        Text("Stop")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        viewModel.startSession()
                    }) {
                        Text("Start")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
