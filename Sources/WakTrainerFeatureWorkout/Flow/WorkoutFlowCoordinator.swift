//
//  WorkoutFlowCoordinator.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-09-19.
//

import Foundation
import WakTrainerDomainWorkout

@MainActor
final class WorkoutFlowCoordinator: ObservableObject {

    enum State {
        case selection
        case session(WorkoutDefinition)
    }

    @Published private(set) var state: State = .selection

    func selectWorkout(_ workout: WorkoutDefinition) {
        state = .session(workout)
    }

    func returnToSelection() {
        state = .selection
    }
}
