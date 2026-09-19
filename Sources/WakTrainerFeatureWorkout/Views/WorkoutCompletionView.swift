
import SwiftUI

struct WorkoutCompletionView: View {

    let result: WorkoutFeatureResult
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("운동 완료")
                .font(.largeTitle)
                .bold()

            Text(result.workoutName)
                .font(.title2)

            VStack(spacing: 12) {
                resultRow(
                    title: "운동 시간",
                    value: formattedDuration
                )

                resultRow(
                    title: "거리",
                    value: String(
                        format: "%.2f km",
                        result.distanceMeters / 1000
                    )
                )

                resultRow(
                    title: "칼로리",
                    value: "\(Int(result.activeCalories)) kcal"
                )

                resultRow(
                    title: "걸음 수",
                    value: "\(Int(result.stepCount))"
                )
            }

            Spacer()

            Button("완료") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private func resultRow(
        title: String,
        value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }

    private var formattedDuration: String {
        let totalSeconds = Int(result.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(
                format: "%02d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format: "%02d:%02d",
            minutes,
            seconds
        )
    }
}
