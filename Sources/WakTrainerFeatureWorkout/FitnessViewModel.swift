//
//  FitnessViewModel.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-08-25.
//

import SwiftUI
import HealthKit
import WakTrainerCoreModels
import WakTrainerServiceHealthKit

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var stepCount: Double = 0
    @Published var distanceMeters: Double = 0
    
    // UI 표시용 (킬로미터 단위 변환)
    var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
    
    private let healthKitManager: HealthKitManagerProtocol = HealthKitManager()
    private var observationTask: Task<Void, Never>?

    // 1. 권한 요청 및 수집 시작
    func startMonitoring() {
        Task {
            do {
                let isAuthorized = try await healthKitManager.requestAuthorization()
                guard isAuthorized else {
                    print("HealthKit 권한이 거부되었습니다.")
                    return
                }

                startObserving()
            } catch {
                print("권한 요청 중 오류 발생: \(error)")
            }
        }
    }

    private func startObserving() {
        observationTask?.cancel()

        observationTask = Task {
            let stream = healthKitManager.startObservingData()
            
            for await snapshot in stream {
                // 실시간 수치 업데이트
                self.heartRate = snapshot.heartRate
                self.activeCalories = snapshot.activeCalories
                self.stepCount = snapshot.stepCount
                self.distanceMeters = snapshot.distance // 👈 추가된 거리 데이터 수신
            }
        }
    }

    // 2. 수집 중단
    func stopMonitoring() {
        observationTask?.cancel()
        observationTask = nil
    }
}
