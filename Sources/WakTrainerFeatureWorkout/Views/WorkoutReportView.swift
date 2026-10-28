import Charts
import MapKit
import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerServiceLocation

struct WorkoutReportView: View {

    @StateObject private var viewModel: WorkoutReportViewModel

    private let weightUnit: WorkoutWeightUnit
    private let onDone: () -> Void

    init(
        session: WorkoutSession,
        maximumHeartRate: Double? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: WorkoutReportViewModel(
                session: session,
                maximumHeartRate: maximumHeartRate
            )
        )

        self.weightUnit = weightUnit
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
                    strengthLocationSection
                    strengthInsightsSection
                }

                if let cardio = viewModel.report.cardio {
                    cardioSection(cardio)
                    cardioInsightsSection(cardio)
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
                VStack(alignment: .leading, spacing: 0) {
                    heartSummaryRow("Maximum", value: viewModel.report.heart.maximumHeartRate)
                    Divider()
                    heartSummaryRow("Average", value: viewModel.report.heart.averageHeartRate)
                    Divider()
                    heartSummaryRow("Minimum", value: viewModel.report.heart.minimumHeartRate)
                }
                .padding(.horizontal, 14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                if !viewModel.heartRateSamples.isEmpty {
                    Chart {
                        if viewModel.report.heart.zones.isEmpty {
                            ForEach(viewModel.heartRateSamples) { sample in
                                LineMark(
                                    x: .value("Time", sample.startDate),
                                    y: .value("Heart Rate", sample.value)
                                )
                                .foregroundStyle(.green)
                            }
                        } else {
                            ForEach(heartChartSegments) { segment in
                                LineMark(
                                    x: .value("Time", segment.start),
                                    y: .value("Heart Rate", segment.startBPM),
                                    series: .value("Segment", segment.id)
                                )
                                .foregroundStyle(heartZoneColor(segment.zone))
                                .interpolationMethod(.linear)
                                LineMark(
                                    x: .value("Time", segment.end),
                                    y: .value("Heart Rate", segment.endBPM),
                                    series: .value("Segment", segment.id)
                                )
                                .foregroundStyle(heartZoneColor(segment.zone))
                                .interpolationMethod(.linear)
                            }
                        }
                    }
                    .frame(height: 180)
                    .chartYAxisLabel("bpm")

                    if !viewModel.report.heart.zones.isEmpty {
                        heartZoneLegend
                    }
                }

                if !viewModel.report.heart.zones.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Heart Rate Zones")
                            .font(.headline)
                        Text("Distribution of recorded heart rate samples")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    private var strengthLocationSection: some View {
        reportSection(title: "Workout Location") {
            if let point = viewModel.session.route.first {
                Map(initialPosition: .region(
                    MKCoordinateRegion(
                        center: point.coordinate,
                        latitudinalMeters: 350,
                        longitudinalMeters: 350
                    )
                )) {
                    Marker("Workout Location", coordinate: point.coordinate)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Label(
                    "Location unavailable for this workout.",
                    systemImage: "location.slash"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                            weightUnit.fromKilograms(strength.totalVolumeKilograms),
                            suffix: " \(weightUnit.rawValue)"
                        )
                    )

                    reportMetric(
                        title: "Maximum Weight",
                        value: formatNumber(
                            weightUnit.fromKilograms(strength.maximumWeightKilograms),
                            suffix: " \(weightUnit.rawValue)"
                        )
                    )

                    reportMetric(
                        title: "Estimated 1RM",
                        value: formatNumber(
                            weightUnit.fromKilograms(strength.bestEstimatedOneRepMaxKilograms),
                            suffix: " \(weightUnit.rawValue)",
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

    // Insights are computed strictly from saved workout data; missing
    // sensor metrics remain unavailable rather than inferred.
    private var strengthInsightsSection: some View {
        let exercises = viewModel.strengthExerciseRecords
        let sets = exercises.flatMap { $0.strengthSets }.filter(\.isCompleted)
        let working = sets.filter { !$0.isWarmup }
        let reps = working.reduce(0) { $0 + ($1.repetitions ?? 0) }
        let volume = working.reduce(0.0) {
            $0 + max(0, $1.weightKilograms ?? 0) * Double(max(0, $1.repetitions ?? 0))
        }
        return reportSection(title: "Strength Analysis") {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                reportMetric(title: "Exercises", value: "\(exercises.count)")
                reportMetric(title: "Warm-up Sets", value: "\(sets.count - working.count)")
                reportMetric(title: "Avg Reps / Working Set",
                             value: working.isEmpty ? "-" : String(format: "%.1f", Double(reps) / Double(working.count)))
                reportMetric(title: "Working Set Volume",
                             value: formatNumber(weightUnit.fromKilograms(volume), suffix: " \(weightUnit.rawValue)"))
                reportMetric(title: "Sets / Exercise",
                             value: exercises.isEmpty ? "-" : String(format: "%.1f", Double(sets.count) / Double(exercises.count)))
                reportMetric(title: "Training Density",
                             value: viewModel.report.summary.activeDuration > 0 ?
                                 String(format: "%.1f sets/min", Double(working.count) * 60 / viewModel.report.summary.activeDuration) : "-")
            }
            Text("Analysis excludes warm-up sets from working volume and repetition averages. Historical progress requires comparisons with earlier sessions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func cardioInsightsSection(_ cardio: WorkoutCardioReport) -> some View {
        let summary = viewModel.report.summary
        let active = summary.activeDuration
        let elapsed = summary.elapsedDuration
        return reportSection(title: "Cardio Analysis") {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                reportMetric(title: "Moving Time Share",
                             value: elapsed > 0 ? String(format: "%.0f%%", 100 * active / elapsed) : "-")
                reportMetric(title: "Calories / Active Minute",
                             value: active > 0 && summary.activeCalories != nil ?
                                 String(format: "%.1f kcal/min", (summary.activeCalories ?? 0) * 60 / active) : "-")
                reportMetric(title: "Steps / Active Minute",
                             value: active > 0 && summary.stepCount != nil ?
                                 String(format: "%.0f steps/min", (summary.stepCount ?? 0) * 60 / active) : "-")
                reportMetric(title: "Split Count", value: "\(cardio.splits.count)")
            }
            Text("Statistics use recorded values only. Device and location accuracy may affect results.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private func heartSummaryRow(_ title: String, value: Double?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatNumber(value, suffix: " BPM"))
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private struct HeartChartSegment: Identifiable {
        let id: Int
        let start: Date
        let end: Date
        let startBPM: Double
        let endBPM: Double
        let zone: Int
    }

    private var heartChartSegments: [HeartChartSegment] {
        let samples = viewModel.heartRateSamples
            .filter { $0.value.isFinite && $0.value > 0 }
            .sorted { $0.startDate < $1.startDate }
        let boundaries = viewModel.report.heart.zones
            .compactMap(\.upperBoundBPM)
            .sorted()
        guard boundaries.count == 4, samples.count >= 2 else { return [] }

        var result: [HeartChartSegment] = []
        for index in 0..<(samples.count - 1) {
            let first = samples[index]
            let second = samples[index + 1]
            let duration = second.startDate.timeIntervalSince(first.startDate)
            guard duration > 0 else { continue }
            var fractions: [Double] = [0, 1]
            if first.value != second.value {
                for boundary in boundaries {
                    let fraction = (boundary - first.value) / (second.value - first.value)
                    if fraction > 0 && fraction < 1 { fractions.append(fraction) }
                }
            }
            fractions.sort()
            for part in 0..<(fractions.count - 1) {
                let low = fractions[part]
                let high = fractions[part + 1]
                let midBPM = first.value + (second.value - first.value) * (low + high) / 2
                let zone = boundaries.filter { midBPM >= $0 }.count + 1
                result.append(HeartChartSegment(
                    id: result.count,
                    start: first.startDate.addingTimeInterval(duration * low),
                    end: first.startDate.addingTimeInterval(duration * high),
                    startBPM: first.value + (second.value - first.value) * low,
                    endBPM: first.value + (second.value - first.value) * high,
                    zone: zone
                ))
            }
        }
        return result
    }

    private var heartZoneLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heart Rate Zone Colors")
                .font(.subheadline.bold())

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(
                    viewModel.report.heart.zones,
                    id: \.level.rawValue
                ) { zone in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(heartZoneColor(zone.level.rawValue))
                            .frame(width: 10, height: 10)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Zone \(zone.level.rawValue) · \(heartZoneDescription(zone.level.rawValue))")
                                .font(.caption.bold())
                                .fixedSize(horizontal: false, vertical: true)

                            Text(zoneRange(zone))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func heartZoneDescription(_ level: Int) -> String {
        switch level {
        case 1: "Recovery"
        case 2: "Easy"
        case 3: "Moderate"
        case 4: "Hard"
        default: "Maximum"
        }
    }

    private func heartZoneRow(_ zone: WorkoutHeartRateZone) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(heartZoneColor(zone.level.rawValue))
                .frame(width: 5, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Zone \(zone.level.rawValue)")
                        .font(.subheadline.bold())
                    Text(zoneRange(zone))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", zone.samplePercentage))
                        .font(.subheadline.monospacedDigit())
                }
                ProgressView(value: zone.samplePercentage, total: 100)
                    .tint(heartZoneColor(zone.level.rawValue))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func zoneRange(_ zone: WorkoutHeartRateZone) -> String {
        let low = Int(zone.lowerBoundBPM.rounded(.up))
        if let high = zone.upperBoundBPM {
            return "\(low)–\(Int(high.rounded(.up)) - 1) bpm"
        }
        return "\(low)+ bpm"
    }

    private func heartZoneColor(_ level: Int) -> Color {
        switch level {
        case 1: .blue
        case 2: .green
        case 3: .yellow
        case 4: .orange
        default: .red
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
            format: "%.1f %@ × %@",
            weightUnit.fromKilograms(weight),
            weightUnit.rawValue,
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
