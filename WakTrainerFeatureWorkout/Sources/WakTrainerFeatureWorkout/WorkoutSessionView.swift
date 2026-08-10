import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer

public struct WorkoutSessionView: View {
    @StateObject private var viewModel: WorkoutSessionViewModel

    public init(viewModel: WorkoutSessionViewModel = WorkoutSessionViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 20) {
            RetroTimerView()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Heart Rate:")
                        .bold()
                    Text("\(Int(viewModel.currentSnapshot.heartRate)) BPM")
                }
                
                HStack {
                    Text("Distance:")
                        .bold()
                    Text(String(format: "%.2f km", viewModel.totalDistance / 1000.0))
                }
            }
            .font(.title3)
            .padding()
            
            Button(action: {
                Task {
                    if viewModel.isSessionActive {
                        await viewModel.stopSession()
                    } else {
                        await viewModel.startSession()
                    }
                }
            }) {
                Text(viewModel.isSessionActive ? "End Workout" : "Start Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isSessionActive ? Color.red : Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
