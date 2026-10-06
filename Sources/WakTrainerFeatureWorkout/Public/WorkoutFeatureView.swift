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

    @StateObject private var coordinator: WorkoutFlowCoordinator

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase
    private let initialCategory: WorkoutCategory
    private let maximumHeartRate: Double?
    private let onCancelled: (() -> Void)?
    private let onFinished: (WorkoutSession) -> Void

    public init(
        maximumHeartRate: Double? = nil,
        onFinished: @escaping (WorkoutSession) -> Void
    ) {
        self.init(
            initialWorkout: nil,
            initialCategory: .strength,
            maximumHeartRate: maximumHeartRate,
            onCancelled: nil,
            onFinished: onFinished
        )
    }

    init(
        initialWorkout: WorkoutDefinition?,
        initialCategory: WorkoutCategory = .strength,
        maximumHeartRate: Double? = nil,
        onCancelled: (() -> Void)? = nil,
        onFinished: @escaping (WorkoutSession) -> Void
    ) {
        let repository = LocalWorkoutCatalogRepository()

        self.fetchWorkoutsUseCase = FetchWorkoutsUseCase(
            repository: repository
        )

        self.initialCategory = initialCategory
        self.maximumHeartRate = maximumHeartRate
        self.onCancelled = onCancelled
        self.onFinished = onFinished

        _coordinator = StateObject(
            wrappedValue: WorkoutFlowCoordinator(
                initialWorkout: initialWorkout
            )
        )
    }

    public var body: some View {
        NavigationStack {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.state {
        case .selection:
            WorkoutSelectionView(
                fetchWorkoutsUseCase: fetchWorkoutsUseCase,
                initialCategory: initialCategory,
                onCancel: onCancelled
            ) { workout in
                coordinator.selectWorkout(workout)
            }

        case .session(let workout):
            WorkoutSessionView(
                workout: workout,
                onCancel: {
                    coordinator.returnToSelection()
                },
                onFinished: { session in
                    coordinator.finishWorkout(session)
                }
            )

        case .completion(let session):
            WorkoutReportView(
                session: session,
                maximumHeartRate: maximumHeartRate
            ) {
                onFinished(session)
            }
        }
    }
}
