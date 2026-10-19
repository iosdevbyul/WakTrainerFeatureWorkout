import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerFeatureWorkout

@MainActor
@Suite("DebugWorkoutSimulator")
struct DebugWorkoutSimulatorTests {
    @Test("running produces bounded heart rate, increasing distance and synthetic sample provenance")
    func runningData() {
        var simulator = DebugWorkoutSimulator()
        let origin = Date(timeIntervalSince1970: 1_800_000_000)
        for second in 0..<120 {
            simulator.advance(
                at: origin.addingTimeInterval(TimeInterval(second)),
                category: "cardio", workoutID: "running"
            )
        }
        #expect(simulator.heartRate >= 65 && simulator.heartRate <= 185)
        #expect(simulator.distance > 0)
        #expect(simulator.steps > 0)
        #expect(simulator.route.count == 120)
        #expect(simulator.health.summary.activeCalories ?? 0 > 0)
        #expect(simulator.health.samples.count >= 120)
        #expect(simulator.health.samples.allSatisfy {
            $0.sourceName == "WakTrainer Debug Simulator"
        })
    }

    @Test("strength does not fabricate GPS distance")
    func strengthData() {
        var simulator = DebugWorkoutSimulator()
        simulator.advance(at: Date(), category: "strength", workoutID: "strength_training")
        #expect(simulator.route.isEmpty)
        #expect(simulator.distance == 0)
        #expect(simulator.heartRate > 0)
    }
}
