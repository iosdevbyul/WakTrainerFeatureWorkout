//
//  WorkoutSessionViewModel.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-08-25.
//

import Foundation
import Combine
import CoreLocation
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceLocation
import WakTrainerServiceHealthKit
import WakTrainerFeatureTimer

final class WorkoutSessionViewModel: ObservableObject {

    // MARK: - Workout

    public let workout: WorkoutDefinition

    // MARK: - Dependencies

    private let healthKitManager: HealthKitManagerProtocol
    private let locationManager: LocationManager

    public private(set) var timerManager: TimerManager

    // MARK: - Health Data

    @Published public private(set) var heartRate: Double = 0
    @Published public private(set) var activeCalories: Double = 0
    @Published public private(set) var stepCount: Double = 0
    @Published public private(set) var distanceMeters: Double = 0

    // MARK: - Location Data

    @Published public private(set) var userLocation: CLLocation?
    @Published public private(set) var routeCoordinates: [CLLocationCoordinate2D] = []

    // MARK: - Timer Data

    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public private(set) var timerState: TimerState = .idle
    @Published public private(set) var laps: [LapItem] = []

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var healthTask: Task<Void, Never>?

    // MARK: - Initializer

    public init(
        workout: WorkoutDefinition,
        healthKitManager: HealthKitManagerProtocol = HealthKitManager(),
        locationManager: LocationManager = LocationManager(),
        timerManager: TimerManager = TimerManager()
    ) {
        self.workout = workout
        self.healthKitManager = healthKitManager
        self.locationManager = locationManager
        self.timerManager = timerManager

        setupSubscriptions()
    }

    deinit {
        healthTask?.cancel()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        locationManager.$userLocation
            .receive(on: DispatchQueue.main)
            .assign(to: &$userLocation)

        locationManager.$routeCoordinates
            .receive(on: DispatchQueue.main)
            .assign(to: &$routeCoordinates)

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

    // MARK: - Workout Actions

    public func startWorkout() async {
        _ = try? await healthKitManager.requestAuthorization()

        if workout.requiresLocationTracking {
            locationManager.requestLocationPermission()
        }

        await MainActor.run {
            timerManager.start()

            if workout.requiresLocationTracking {
                locationManager.startTracking()
            }
        }

        startHealthObservation()
    }

    public func pauseWorkout() {
        timerManager.pause()
    }

    public func resumeWorkout() {
        timerManager.start()
    }

    public func stopWorkout() {
        timerManager.stop()

        if workout.requiresLocationTracking {
            locationManager.stopTracking()
        }

        healthTask?.cancel()
        healthTask = nil

        Task {
            await healthKitManager.stopObservingData()
        }
    }

    public func recordLap() {
        timerManager.recordLap()
    }

    // MARK: - Health Observation

    private func startHealthObservation() {
        healthTask?.cancel()

        healthTask = Task { [weak self] in
            guard let self else {
                return
            }

            let stream = healthKitManager.startObservingData()

            for await snapshot in stream {
                guard !Task.isCancelled else {
                    break
                }

                await MainActor.run {
                    self.heartRate = snapshot.heartRate
                    self.activeCalories = snapshot.activeCalories
                    self.stepCount = snapshot.stepCount
                    self.distanceMeters = snapshot.distance
                }
            }
        }
    }

    // MARK: - UI Values

    public var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
    
    func makeResult() -> WorkoutFeatureResult {
        WorkoutFeatureResult(
            workoutID: workout.id,
            workoutName: workout.name,
            duration: elapsedTime,
            distanceMeters: distanceMeters,
            activeCalories: activeCalories,
            stepCount: stepCount
        )
    }
}
