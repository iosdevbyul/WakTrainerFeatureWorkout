//
//  WorkoutFlowCoordinator.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Foundation
import WakTrainerCoreModels
import WakTrainerDomainWorkout

@MainActor
final class WorkoutFlowCoordinator: ObservableObject {

    enum State {
        case selection
        case session(WorkoutDefinition)
        case completion(WorkoutSession)
    }

    @Published private(set) var state: State

    init(
        initialWorkout: WorkoutDefinition? = nil
    ) {
        if let initialWorkout {
            state = .session(initialWorkout)
        } else {
            state = .selection
        }
    }

    func selectWorkout(_ workout: WorkoutDefinition) {
        state = .session(workout)
    }

    func returnToSelection() {
        state = .selection
    }

    func finishWorkout(_ session: WorkoutSession) {
        state = .completion(session)
    }
}
