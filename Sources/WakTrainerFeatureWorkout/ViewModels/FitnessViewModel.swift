//
//  FitnessViewModel.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-08-25.
//

import Foundation
import Combine
import CoreLocation
import WakTrainerCoreModels
import WakTrainerServiceLocation
import WakTrainerServiceHealthKit
import WakTrainerFeatureTimer

public final class FitnessViewModel: ObservableObject {
    // MARK: - Dependencies
    private let healthKitManager: HealthKitManagerProtocol
    private let locationManager: LocationManager
    public private(set) var timerManager: TimerManager

    // MARK: - Published Properties (UI Binding)
    // 1. HealthKit Data
    @Published public private(set) var heartRate: Double = 0
    @Published public private(set) var activeCalories: Double = 0
    @Published public private(set) var stepCount: Double = 0
    @Published public private(set) var distanceMeters: Double = 0
    
    // 2. Location Data
    @Published public private(set) var userLocation: CLLocation?
    @Published public private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    
    // 3. Timer Data
    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public private(set) var timerState: TimerState = .idle
    @Published public private(set) var laps: [LapItem] = []

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var healthTask: Task<Void, Never>?

    // MARK: - Initializer (DI)
    public init(
        healthKitManager: HealthKitManagerProtocol = HealthKitManager(),
        locationManager: LocationManager = LocationManager(),
        timerManager: TimerManager = TimerManager()
    ) {
        self.healthKitManager = healthKitManager
        self.locationManager = locationManager
        self.timerManager = timerManager
        
        setupSubscriptions()
    }

    deinit {
        healthTask?.cancel()
    }

    // MARK: - Private Setup
    private func setupSubscriptions() {
        // LocationManager 상태 구독
        locationManager.$userLocation
            .receive(on: DispatchQueue.main)
            .assign(to: &$userLocation)

        locationManager.$routeCoordinates
            .receive(on: DispatchQueue.main)
            .assign(to: &$routeCoordinates)

        // TimerManager 상태 구독
        timerManager.$elapsedTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$elapsedTime)

        timerManager.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$timerState)

        timerManager.$laps
            .receive(on: DispatchQueue.main)
            .assign(to: &$laps)
    }

    // MARK: - User Intent / Actions
    
    /// 운동 시작 (권한 요청 -> 타이머 / GPS / HealthKit 수집 동시 시작)
    public func startWorkout() async {
        // 1. 권한 요청
        _ = try? await healthKitManager.requestAuthorization()
        locationManager.requestLocationPermission()

        // 2. 메인 스레드에서 타이머 & GPS 시작
        await MainActor.run {
            timerManager.start()
            locationManager.startTracking()
        }

        // 3. HealthKit AsyncStream 관찰 시작
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = self.healthKitManager.startObservingData()
            
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                
                // UI 갱신 데이터만 메인 스레드로 전송
                await MainActor.run {
                    self.heartRate = snapshot.heartRate
                    self.activeCalories = snapshot.activeCalories
                    self.stepCount = snapshot.stepCount
                    self.distanceMeters = snapshot.distance
                }
            }
        }
    }

    /// 운동 일시정지
    public func pauseWorkout() {
        timerManager.pause()
    }

    /// 운동 재개
    public func resumeWorkout() {
        timerManager.start()
    }

    /// 운동 종료
    public func stopWorkout() {
        timerManager.stop()
        locationManager.stopTracking()
        
        healthTask?.cancel()
        healthTask = nil
        
        Task {
            await healthKitManager.stopObservingData()
        }
    }

    /// 랩 타임 기록
    public func recordLap() {
        timerManager.recordLap()
    }

    // MARK: - Computed Properties for UI
    public var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
}
