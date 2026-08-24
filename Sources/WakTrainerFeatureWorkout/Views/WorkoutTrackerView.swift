//
//  WorkoutTrackerView.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-08-25.
//

import SwiftUI
import HealthKit
import WakTrainerCoreModels

public struct WorkoutTrackerView: View {
    @StateObject private var viewModel = FitnessViewModel()
    
    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            // 헤더
            Text("운동 트래킹")
                .font(.largeTitle)
                .bold()
                .padding(.top, 20)

            // 데이터 표시 카드 영역
            VStack(spacing: 16) {
                MetricCard(
                    title: "심박수",
                    value: "\(Int(viewModel.heartRate))",
                    unit: "BPM",
                    iconName: "heart.fill",
                    iconColor: .red
                )

                MetricCard(
                    title: "소모 칼로리",
                    value: "\(Int(viewModel.activeCalories))",
                    unit: "kcal",
                    iconName: "flame.fill",
                    iconColor: .orange
                )

                MetricCard(
                    title: "걸음 수",
                    value: "\(Int(viewModel.stepCount))",
                    unit: "걸음",
                    iconName: "shoeprints.fill",
                    iconColor: .blue
                )

                MetricCard(
                    title: "이동 거리",
                    value: String(format: "%.2f", viewModel.distanceKilometers),
                    unit: "km",
                    iconName: "figure.walk",
                    iconColor: .green
                )
            }
            .padding(.horizontal)

            Spacer()

            // 제어 버튼 영역
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.startMonitoring()
                }) {
                    Text("운동 시작")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: {
                    viewModel.stopMonitoring()
                }) {
                    Text("운동 종료")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

// MARK: - Subview: metric 카드 레이아웃
private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let iconName: String
    let iconColor: Color

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .bold()
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground)) // 👈 Color(uiColor:) 대신 이와 같이 변경
        .cornerRadius(16)
    }
}
