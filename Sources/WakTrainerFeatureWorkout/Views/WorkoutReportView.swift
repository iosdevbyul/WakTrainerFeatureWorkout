import Charts
import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceLocation

struct WorkoutReportView: View {

    @StateObject private var viewModel: WorkoutReportViewModel

    private let onDone: () -> Void

    init(
        session: WorkoutSession,
        maximumHeartRate: Double? = nil,
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: WorkoutReportViewModel(
                session: session,
                maximumHeartRate: maximumHeartRate
            )
        )

        self.onDone = onDone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summarySection

                if hasHeartData {
                    heartSection
                }

                if let strength = viewModel.report.strength {
                    strengthSection(strength)
                }

                if let cardio = viewModel.report.cardio {
                    cardioSection(cardio)
                }

                detailsSection

                Button("Done") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationTitle("Workout Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Workout Complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.report.workout.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(
                formatDuration(
                    viewModel.report.summary.activeDuration
                )
            )
            .font(.title3.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        reportSection(title: "Summary") {
            LazyVGrid(
                columns: gridColumns,
                spacing: 12
            ) {
                reportMetric(
                    title: "Active Time",
                    value: formatDuration(
                        viewModel.report.summary.activeDuration
                    )
                )

                reportMetric(
                    title: "Calories",
                    value: formatNumber(
                        viewModel.report.summary.activeCalories,
                        suffix: " kcal"
                    )
                )

                reportMetric(
                    title: "Distance",
                    value: formatDistance(
                        viewModel.report.summary.distanceMeters
                    )
                )

                reportMetric(
                    title: "Average Heart Rate",
                    value: formatNumber(
                        viewModel.report.summary.averageHeartRate,
                        suffix: " bpm"
                    )
                )
            }
        }
    }

    private var heartSection: some View {
        reportSection(title: "Heart") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    reportMetric(
                        title: "Average",
                        value: formatNumber(
                            viewModel.report.heart.averageHeartRate,
                            suffix: " bpm"
                        )
                    )

                    reportMetric(
                        title: "Maximum",
                        value: formatNumber(
                            viewModel.report.heart.maximumHeartRate,
                            suffix: " bpm"
                        )
                    )

                    reportMetric(
                        title: "Minimum",
                        value: formatNumber(
                            viewModel.report.heart.minimumHeartRate,
                            suffix: " bpm"
                        )
                    )
                }

                if !viewModel.heartRateSamples.isEmpty {
                    Chart(viewModel.heartRateSamples) { sample in
                        LineMark(
                            x: .value(
                                "Time",
                                sample.startDate
                            ),
                            y: .value(
                                "Heart Rate",
                                sample.value
                            )
                        )
                    }
                    .frame(height: 180)
                    .chartYAxisLabel("bpm")
                }

                if !viewModel.report.heart.zones.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(
                            viewModel.report.heart.zones,
                            id: \.level.rawValue
                        ) { zone in
                            heartZoneRow(zone)
                        }
                    }
                }
            }
        }
    }

    private func strengthSection(
        _ strength: WorkoutStrengthReport
    ) -> some View {
        reportSection(title: "Strength") {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: 12
                ) {
                    reportMetric(
                        title: "Working Sets",
                        value: "\(strength.workingSets)"
                    )

                    reportMetric(
                        title: "Total Repetitions",
                        value: "\(strength.totalRepetitions)"
                    )

                    reportMetric(
                        title: "Total Volume",
                        value: formatNumber(
                            strength.totalVolumeKilograms,
                            suffix: " kg"
                        )
                    )

                    reportMetric(
                        title: "Maximum Weight",
                        value: formatNumber(
                            strength.maximumWeightKilograms,
                            suffix: " kg"
                        )
                    )

                    reportMetric(
                        title: "Estimated 1RM",
                        value: formatNumber(
                            strength.bestEstimatedOneRepMaxKilograms,
                            suffix: " kg",
                            decimals: 1
                        )
                    )

                    reportMetric(
                        title: "Average Rest",
                        value: strength.averageRestDuration.map(
                            formatDuration
                        ) ?? "-"
                    )
                }

                if !viewModel.strengthExerciseRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Exercises")
                            .font(.headline)

                        ForEach(
                            viewModel.strengthExerciseRecords
                        ) { exercise in
                            strengthExerciseCard(
                                exercise
                            )
                        }
                    }
                }
            }
        }
    }

    private func cardioSection(
        _ cardio: WorkoutCardioReport
    ) -> some View {
        reportSection(title: "Cardio") {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: 12
                ) {
                    reportMetric(
                        title: "Distance",
                        value: formatDistance(
                            cardio.distanceMeters
                        )
                    )

                    reportMetric(
                        title: "Average Pace",
                        value: formatPace(
                            cardio.averagePaceSecondsPerKilometer
                        )
                    )

                    reportMetric(
                        title: "Average Speed",
                        value: formatSpeed(
                            cardio.averageSpeedMetersPerSecond
                        )
                    )

                    reportMetric(
                        title: "Maximum Speed",
                        value: formatSpeed(
                            cardio.maximumSpeedMetersPerSecond
                        )
                    )

                    reportMetric(
                        title: "Cadence",
                        value: formatNumber(
                            cardio.averageCadence,
                            suffix: " /min"
                        )
                    )

                    reportMetric(
                        title: "Average Power",
                        value: formatNumber(
                            cardio.averagePowerWatts,
                            suffix: " W"
                        )
                    )

                    reportMetric(
                        title: "Elevation Gain",
                        value: formatNumber(
                            cardio.elevationGainMeters,
                            suffix: " m"
                        )
                    )

                    reportMetric(
                        title: "GPS Distance",
                        value: formatDistance(
                            cardio.routeDistanceMeters
                        )
                    )
                }

                if viewModel.session.route.count >= 2 {
                    routeMapSection(cardio)
                }

                if !cardio.splits.isEmpty {
                    cardioSplitsSection(
                        cardio.splits
                    )
                }
            }
        }
    }

    private func routeMapSection(
        _ cardio: WorkoutCardioReport
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Route")
                    .font(.headline)

                Spacer()

                if let distance =
                        cardio.routeDistanceMeters {
                    Text(
                        formatDistance(
                            distance
                        )
                    )
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            WorkoutMapView(
                routePoints:
                    viewModel.session.route
            )
            .frame(height: 260)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )
        }
    }

    private func cardioSplitsSection(
        _ splits: [WorkoutCardioSplit]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Splits")
                .font(.headline)

            ForEach(splits) { split in
                HStack(spacing: 12) {
                    Text(
                        splitLabel(split)
                    )
                    .frame(
                        width: 70,
                        alignment: .leading
                    )
                    .foregroundStyle(.secondary)

                    Text(
                        formatDuration(
                            split.duration
                        )
                    )
                    .monospacedDigit()

                    Spacer()

                    Text(
                        formatPace(
                            split.paceSecondsPerKilometer
                        )
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func splitLabel(
        _ split: WorkoutCardioSplit
    ) -> String {
        if split.distanceMeters >= 999.5 {
            return "\(split.index) km"
        }

        return String(
            format: "%.0f m",
            split.distanceMeters
        )
    }

    private var detailsSection: some View {
        reportSection(title: "Details") {
            VStack(spacing: 12) {
                detailRow(
                    title: "Elapsed Time",
                    value: formatDuration(
                        viewModel.report.summary.elapsedDuration
                    )
                )

                detailRow(
                    title: "Paused Time",
                    value: formatDuration(
                        viewModel.report.summary.pausedDuration
                    )
                )

                detailRow(
                    title: "Steps",
                    value: formatNumber(
                        viewModel.report.summary.stepCount
                    )
                )

                detailRow(
                    title: "Heart Rate Samples",
                    value: "\(viewModel.report.heart.sampleCount)"
                )
            }
        }
    }

    private var hasHeartData: Bool {
        viewModel.report.heart.sampleCount > 0 ||
        viewModel.report.heart.averageHeartRate != nil ||
        viewModel.report.heart.maximumHeartRate != nil ||
        viewModel.report.heart.minimumHeartRate != nil
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }

    @ViewBuilder
    private func reportSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            content()
        }
    }

    private func reportMetric(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background(
            Color.secondary.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14
            )
        )
    }

    private func heartZoneRow(
        _ zone: WorkoutHeartRateZone
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Zone \(zone.level.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(
                    String(
                        format: "%.0f%%",
                        zone.samplePercentage
                    )
                )
                .font(.subheadline.monospacedDigit())
            }

            ProgressView(
                value: zone.samplePercentage,
                total: 100
            )
        }
    }

    private func strengthExerciseCard(
        _ exercise: WorkoutExerciseRecord
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(exercise.name)
                        .font(.headline)

                    if let equipment =
                            exercise
                                .strengthEquipment {
                        Text(
                            equipment.displayName
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Spacer()

                Text(
                    "\(exercise.strengthSets.filter(\.isCompleted).count) sets"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(
                exercise.strengthSets
                    .filter(\.isCompleted)
            ) { set in
                strengthSetRow(set)
            }
        }
        .padding(14)
        .background(
            Color.secondary.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14
            )
        )
    }

    private func strengthSetRow(
        _ set: StrengthSetRecord
    ) -> some View {
        HStack {
            Text(
                set.isWarmup
                    ? "Warm-up \(set.setNumber)"
                    : "Set \(set.setNumber)"
            )

            Spacer()

            Text(
                strengthSetValue(set)
            )
            .fontWeight(.semibold)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func detailRow(
        title: String,
        value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private func strengthSetValue(
        _ set: StrengthSetRecord
    ) -> String {
        let repetitions = set.repetitions.map(
            String.init
        ) ?? "-"

        guard let weight =
                set.weightKilograms else {
            return "\(repetitions) reps"
        }

        return String(
            format: "%.1f kg × %@",
            weight,
            repetitions
        )
    }

    private func formatDuration(
        _ duration: TimeInterval
    ) -> String {
        let totalSeconds = max(
            0,
            Int(duration)
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

    private func formatPace(
        _ pace: TimeInterval?
    ) -> String {
        guard let pace,
              pace.isFinite,
              pace > 0 else {
            return "-"
        }

        let totalSeconds = Int(pace)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%d:%02d /km",
            minutes,
            seconds
        )
    }

    private func formatDistance(
        _ meters: Double?
    ) -> String {
        guard let meters else {
            return "-"
        }

        return String(
            format: "%.2f km",
            meters / 1_000
        )
    }

    private func formatSpeed(
        _ metersPerSecond: Double?
    ) -> String {
        guard let metersPerSecond else {
            return "-"
        }

        return String(
            format: "%.1f km/h",
            metersPerSecond * 3.6
        )
    }

    private func formatNumber(
        _ value: Double?,
        suffix: String = "",
        decimals: Int = 0
    ) -> String {
        guard let value else {
            return "-"
        }

        return String(
            format: "%.*f%@",
            decimals,
            value,
            suffix
        )
    }

    private func formatNumber(
        _ value: Double,
        suffix: String = "",
        decimals: Int = 0
    ) -> String {
        String(
            format: "%.*f%@",
            decimals,
            value,
            suffix
        )
    }
}
