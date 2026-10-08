//
//  WorkoutFeatureView.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout

public struct WorkoutFeatureView: View {

    @StateObject private var coordinator:
        WorkoutFlowCoordinator

    private let fetchWorkoutsUseCase:
        FetchWorkoutsUseCase
    private let initialCategory:
        WorkoutCategory
    private let restoredSession:
        StoredWorkoutSession?
    private let sessionRepository:
        (any WorkoutSessionRepository)?
    private let preferenceStore:
        any WorkoutLauncherPreferenceStore
    private let weightUnit: WorkoutWeightUnit
    private let maximumHeartRate: Double?
    private let startsFromDirectWorkout: Bool
    private let onCancelled:
        (() -> Void)?
    private let onFinished:
        (WorkoutSession) -> Void

    public init(
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        onFinished:
            @escaping (WorkoutSession) -> Void
    ) {
        self.init(
            initialWorkout: nil,
            initialCategory: .strength,
            restoredSession: nil,
            sessionRepository: nil,
            preferenceStore:
                UserDefaultsWorkoutLauncherPreferenceStore(),
            maximumHeartRate:
                maximumHeartRate,
            weightUnit: weightUnit,
            onCancelled: nil,
            onFinished:
                onFinished
        )
    }

    init(
        initialWorkout:
            WorkoutDefinition?,
        initialCategory:
            WorkoutCategory = .strength,
        restoredSession:
            StoredWorkoutSession? = nil,
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        preferenceStore:
            any WorkoutLauncherPreferenceStore =
                UserDefaultsWorkoutLauncherPreferenceStore(),
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        onCancelled:
            (() -> Void)? = nil,
        onFinished:
            @escaping (WorkoutSession) -> Void
    ) {
        let repository =
            LocalWorkoutCatalogRepository()

        self.fetchWorkoutsUseCase =
            FetchWorkoutsUseCase(
                repository: repository
            )

        self.initialCategory =
            initialCategory
        self.restoredSession =
            restoredSession
        self.sessionRepository =
            sessionRepository
        self.preferenceStore =
            preferenceStore
        self.maximumHeartRate =
            maximumHeartRate
        self.weightUnit = weightUnit
        self.startsFromDirectWorkout =
            initialWorkout != nil
        self.onCancelled =
            onCancelled
        self.onFinished =
            onFinished

        _coordinator = StateObject(
            wrappedValue:
                WorkoutFlowCoordinator(
                    initialWorkout:
                        initialWorkout
                )
        )
    }

    public var body: some View {
        NavigationStack {
            content
        }
    }

    @ViewBuilder
    private var content:
        some View {
        switch coordinator.state {
        case .selection:
            WorkoutSelectionView(
                fetchWorkoutsUseCase:
                    fetchWorkoutsUseCase,
                initialCategory:
                    initialCategory,
                preferenceStore:
                    preferenceStore,
                onCancel:
                    onCancelled
            ) { workout in
                coordinator
                    .selectWorkout(
                        workout
                    )
            }

        case .session(
            let workout
        ):
            WorkoutSessionView(
                workout: workout,
                restoredSession:
                    restoredSessionForWorkout(
                        workout
                    ),
                sessionRepository:
                    sessionRepository,
                weightUnit: weightUnit,
                onCancel: {
                    if startsFromDirectWorkout {
                        onCancelled?()
                    } else {
                        coordinator
                            .returnToSelection()
                    }
                },
                onFinished: {
                    session in
                    coordinator
                        .finishWorkout(
                            session
                        )
                }
            )

        case .completion(
            let session
        ):
            WorkoutReportView(
                session: session,
                maximumHeartRate:
                    maximumHeartRate,
                weightUnit: weightUnit
            ) {
                onFinished(
                    session
                )
            }
        }
    }

    private func restoredSessionForWorkout(
        _ workout:
            WorkoutDefinition
    ) -> StoredWorkoutSession? {
        guard let restoredSession else {
            return nil
        }

        let storedWorkout =
            restoredSession
                .session
                .workout

        if storedWorkout.workoutID
            == workout.id {
            return restoredSession
        }

        if workout.id
            == "strength_training",
           storedWorkout.category
            == WorkoutCategory
                .strength.rawValue {
            return restoredSession
        }

        if workout.id == "cycling",
           storedWorkout.workoutID
            == "outdoor_cycling"
            || storedWorkout.workoutID
                == "indoor_cycling" {
            return restoredSession
        }

        return nil
    }
}
