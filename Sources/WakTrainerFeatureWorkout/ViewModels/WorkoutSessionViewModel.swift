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

@MainActor
final class WorkoutSessionViewModel: ObservableObject {

    // MARK: - Workout

    let workout: WorkoutDefinition
    private let userProfile: UserProfile?

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

    // MARK: - Recorded Metrics

    @Published private(set) var metricSamples: [WorkoutMetricSample] = []
    @Published private(set) var routePoints: [WorkoutRoutePoint] = []
    private var workoutStartDate: Date?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var healthTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        workout: WorkoutDefinition,
        userProfile: UserProfile? = nil,
        healthKitManager: HealthKitManagerProtocol = HealthKitManager(),
        locationManager: (any WorkoutLocationManaging)? = nil,
        timerManager: TimerManager = TimerManager()
    ) {
        self.workout = workout
        self.userProfile = userProfile
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
                .sink { [weak self] location in
                    self?.userLocation = location
                    self?.captureRouteLocation(location)
                }
                .store(in: &cancellables)

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
        guard timerState == .idle else { return }

        metricSamples.removeAll()
        routePoints.removeAll()
        workoutStartDate = Date()
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

                self.heartRate = snapshot.heartRate
                self.activeCalories = snapshot.activeCalories
                self.stepCount = snapshot.stepCount
                self.distanceMeters = snapshot.distance

                let valid: (Double) -> Double? = { value in
                    value.isFinite && value > 0 ? value : nil
                }

                self.metricSamples.append(
                    WorkoutMetricSample(
                        recordedAt: Date(),
                        heartRateBPM: valid(snapshot.heartRate),
                        activeCaloriesKcal: valid(snapshot.activeCalories),
                        stepCount: valid(snapshot.stepCount),
                        distanceMeters: valid(snapshot.distance)
                    )
                )
            }
        }
    }

    // MARK: - UI Values

    var distanceKilometers: Double {
        distanceMeters / 1000.0
    }
    
    private func captureRouteLocation(_ location: CLLocation?) {
        guard workoutStartDate != nil,
              workout.requiresLocationTracking,
              timerState == .running,
              let location,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 65 else {
            return
        }

        routePoints.append(
            WorkoutRoutePoint(
                recordedAt: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracyMeters: location.horizontalAccuracy,
                altitudeMeters: location.verticalAccuracy >= 0
                    ? location.altitude : nil,
                speedMetersPerSecond: location.speed >= 0
                    ? location.speed : nil
            )
        )
    }

    private func makeResult() -> WorkoutFeatureResult {
        WorkoutFeatureResult(
            workoutID: workout.id,
            workoutName: workout.name,
            duration: elapsedTime,
            distanceMeters: distanceMeters,
            activeCalories: activeCalories,
            stepCount: stepCount,
            startedAt: workoutStartDate ?? Date(),
            endedAt: Date(),
            ageAtWorkout: userProfile?.age,
            requiresLocationTracking: workout.requiresLocationTracking,
            metricSamples: metricSamples,
            routePoints: routePoints
        )
    }
}
