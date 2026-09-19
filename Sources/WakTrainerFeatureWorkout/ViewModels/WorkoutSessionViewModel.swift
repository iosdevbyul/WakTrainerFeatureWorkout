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

protocol WorkoutLocationManaging: AnyObject {

    var userLocationPublisher: AnyPublisher<CLLocation?, Never> { get }

    var routeCoordinatesPublisher: AnyPublisher<
        [CLLocationCoordinate2D],
        Never
    > { get }

    func requestLocationPermission()
    func startTracking()
    func stopTracking()
}

extension LocationManager: WorkoutLocationManaging {

    var userLocationPublisher: AnyPublisher<CLLocation?, Never> {
        $userLocation.eraseToAnyPublisher()
    }

    var routeCoordinatesPublisher: AnyPublisher<
        [CLLocationCoordinate2D],
        Never
    > {
        $routeCoordinates.eraseToAnyPublisher()
    }
}

final class WorkoutSessionViewModel: ObservableObject {

    // MARK: - Workout

    let workout: WorkoutDefinition

    // MARK: - Dependencies

    private let healthKitManager: HealthKitManagerProtocol
    private let locationManager: (any WorkoutLocationManaging)?
    private(set) var timerManager: TimerManager

    // MARK: - Health Data

    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var stepCount: Double = 0
    @Published private(set) var distanceMeters: Double = 0

    // MARK: - Location Data

    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []

    // MARK: - Timer Data

    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var laps: [LapItem] = []

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var healthTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        workout: WorkoutDefinition,
        healthKitManager: HealthKitManagerProtocol = HealthKitManager(),
        locationManager: (any WorkoutLocationManaging)? = nil,
        timerManager: TimerManager = TimerManager()
    ) {
        self.workout = workout
        self.healthKitManager = healthKitManager

        if let locationManager {
            self.locationManager = locationManager
        } else if workout.requiresLocationTracking {
            self.locationManager = LocationManager()
        } else {
            self.locationManager = nil
        }

        self.timerManager = timerManager

        setupSubscriptions()
    }

    deinit {
        healthTask?.cancel()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        if let locationManager {
            locationManager.userLocationPublisher
                .receive(on: DispatchQueue.main)
                .assign(to: &$userLocation)

            locationManager.routeCoordinatesPublisher
                .receive(on: DispatchQueue.main)
                .assign(to: &$routeCoordinates)
        }
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

    func startWorkout() async {
        _ = try? await healthKitManager.requestAuthorization()

        if workout.requiresLocationTracking {
            locationManager?.requestLocationPermission()
        }

        await MainActor.run {
            timerManager.start()

            if workout.requiresLocationTracking {
                locationManager?.startTracking()
            }
        }

        startHealthObservation()
    }

    func pauseWorkout() {
        timerManager.pause()
    }

    func resumeWorkout() {
        timerManager.start()
    }

    func finishWorkout() async -> WorkoutFeatureResult {
        let result = makeResult()

        await stopWorkout()

        return result
    }

    private func stopWorkout() async {
        await MainActor.run {
            timerManager.stop()

            if workout.requiresLocationTracking {
                locationManager?.stopTracking()
            }
        }

        healthTask?.cancel()
        healthTask = nil

        await healthKitManager.stopObservingData()
    }

    func recordLap() {
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

    var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
    
    private func makeResult() -> WorkoutFeatureResult {
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
