//
//  WorkoutSessionViewModel.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-07-31.
//

import Foundation
import Combine
import WakTrainerCoreModels
import WakTrainerCoreServices

@MainActor
public final class WorkoutSessionViewModel: ObservableObject {
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public var selectedWorkoutTitle: String = ""
    
    private let healthKitManager: HealthKitManager
    private var timer: Timer?

    // 1. 외부에서 HealthKitManager를 주입받을 때 사용하는 생성자
    public init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    // 2. 기본 생성자: @MainActor 격리 범위 내부에서 안전하게 HealthKitManager() 생성
    public init() {
        self.healthKitManager = HealthKitManager()
    }

    public func startSession() {
        guard !isRunning else { return }
        isRunning = true
        elapsedTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime += 1
            }
        }
    }

    public func stopSession() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}
