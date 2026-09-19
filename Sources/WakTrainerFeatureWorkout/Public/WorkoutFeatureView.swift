//
//  WorkoutFeatureView.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import SwiftUI
import WakTrainerDomainWorkout

public struct WorkoutFeatureView: View {

    @StateObject private var coordinator: WorkoutFlowCoordinator

    private let fetchWorkoutsUseCase: FetchWorkoutsUseCase
    private let onFinished: (WorkoutFeatureResult) -> Void

    public init(
        onFinished: @escaping (WorkoutFeatureResult) -> Void
    ) {
        let repository = LocalWorkoutCatalogRepository()

        self.fetchWorkoutsUseCase = FetchWorkoutsUseCase(
            repository: repository
        )

        self.onFinished = onFinished

        _coordinator = StateObject(
            wrappedValue: WorkoutFlowCoordinator()
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
                fetchWorkoutsUseCase: fetchWorkoutsUseCase
            ) { workout in
                coordinator.selectWorkout(workout)
            }

        case .session(let workout):
            WorkoutSessionView(
                workout: workout,
                onCancel: {
                    coordinator.returnToSelection()
                },
                onFinished: { result in
                    coordinator.finishWorkout(result)
                }
            )

        case .completion(let result):
            WorkoutCompletionView(
                result: result
            ) {
                onFinished(result)
            }
        }
    }
}
