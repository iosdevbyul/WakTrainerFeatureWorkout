import SwiftUI
import WakTrainerCoreModels

struct WorkoutCompletionView: View {

    let session: WorkoutSession
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("운동 완료")
                .font(.largeTitle)
                .bold()

            Text(session.workout.name)
                .font(.title2)

            VStack(spacing: 12) {
                resultRow(
                    title: "운동 시간",
                    value: formattedDuration
                )

                resultRow(
                    title: "거리",
                    value: formattedDistance
                )

                resultRow(
                    title: "칼로리",
                    value: formattedCalories
                )

                resultRow(
                    title: "걸음 수",
                    value: formattedStepCount
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
        let totalSeconds = Int(
            session.timing.activeDuration
        )

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

    private var formattedDistance: String {
        guard let distance =
                session.health.summary.distanceMeters else {
            return "-"
        }

        return String(
            format: "%.2f km",
            distance / 1000
        )
    }

    private var formattedCalories: String {
        guard let calories =
                session.health.summary.activeCalories else {
            return "-"
        }

        return "\(Int(calories)) kcal"
    }

    private var formattedStepCount: String {
        guard let stepCount =
                session.health.summary.stepCount else {
            return "-"
        }

        return "\(Int(stepCount))"
    }
}
