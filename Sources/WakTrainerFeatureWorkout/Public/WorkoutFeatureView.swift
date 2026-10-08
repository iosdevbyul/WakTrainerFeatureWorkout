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
    private let maximumHeartRate: Double?
    private let onCancelled:
        (() -> Void)?
    private let onFinished:
        (WorkoutSession) -> Void

    public init(
        maximumHeartRate: Double? = nil,
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
                onCancel: {
                    coordinator
                        .returnToSelection()
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
                    maximumHeartRate
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
        guard let restoredSession,
              restoredSession
                .session
                .workout
                .workoutID
                == workout.id else {
            return nil
        }

        return restoredSession
    }
}
