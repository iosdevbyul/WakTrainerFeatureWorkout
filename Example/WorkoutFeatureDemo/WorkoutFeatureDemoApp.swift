import SwiftUI
import WakTrainerFeatureWorkout

@main
struct WorkoutFeatureDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoHomeView()
        }
    }
}

struct DemoHomeView: View {
    @State private var completedCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 58))
                    .foregroundStyle(.tint)

                Text("Workout Feature Demo")
                    .font(.largeTitle.bold())

                Text("Tap W to test the workout menu, quick start, strength exercises, timers, and reports.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("Completed workouts in this session: \(completedCount)")
                    .font(.caption)

                NavigationLink("Workout History") {
                    WorkoutHistoryView()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Feature Demo")
            .wakTrainerWorkoutLauncher { _ in
                completedCount += 1
            }
        }
        .tint(.indigo)
    }
}
