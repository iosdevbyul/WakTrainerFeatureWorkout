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
    private let strengthLocationPolicy: StrengthWorkoutLocationPolicy
    private let weightUnit: WorkoutWeightUnit
    private let maximumHeartRate: Double?
    private let startsFromDirectWorkout: Bool
    private let onCancelled:
        (() -> Void)?
    private let onFinished:
        (WorkoutSession) -> Void
    private let onWorkoutUpdate: ((WorkoutLiveSnapshot) -> Void)?

    public init(
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        strengthLocationPolicy: StrengthWorkoutLocationPolicy = .singleLocation,
        onFinished:
            @escaping (WorkoutSession) -> Void,
        onWorkoutUpdate: ((WorkoutLiveSnapshot) -> Void)? = nil
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
            strengthLocationPolicy: strengthLocationPolicy,
            onCancelled: nil,
            onFinished:
                onFinished,
            onWorkoutUpdate: onWorkoutUpdate
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
        strengthLocationPolicy: StrengthWorkoutLocationPolicy = .singleLocation,
        onCancelled:
            (() -> Void)? = nil,
        onFinished:
            @escaping (WorkoutSession) -> Void,
        onWorkoutUpdate: ((WorkoutLiveSnapshot) -> Void)? = nil
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
        self.strengthLocationPolicy = strengthLocationPolicy
        self.startsFromDirectWorkout =
            initialWorkout != nil
        self.onCancelled =
            onCancelled
        self.onFinished =
            onFinished
        self.onWorkoutUpdate = onWorkoutUpdate

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
                strengthLocationPolicy: strengthLocationPolicy,
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
                },
                onWorkoutUpdate: onWorkoutUpdate
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
