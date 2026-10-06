import Charts
import SwiftUI
import WakTrainerCoreModels
import WakTrainerDomainWorkout

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

                Button("완료") {
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
            Text("운동 완료")
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
                    title: "활동 시간",
                    value: formatDuration(
                        viewModel.report.summary.activeDuration
                    )
                )

                reportMetric(
                    title: "칼로리",
                    value: formatNumber(
                        viewModel.report.summary.activeCalories,
                        suffix: " kcal"
                    )
                )

                reportMetric(
                    title: "거리",
                    value: formatDistance(
                        viewModel.report.summary.distanceMeters
                    )
                )

                reportMetric(
                    title: "평균 심박수",
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
                        title: "평균",
                        value: formatNumber(
                            viewModel.report.heart.averageHeartRate,
                            suffix: " bpm"
                        )
                    )

                    reportMetric(
                        title: "최대",
                        value: formatNumber(
                            viewModel.report.heart.maximumHeartRate,
                            suffix: " bpm"
                        )
                    )

                    reportMetric(
                        title: "최소",
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
                        title: "작업 세트",
                        value: "\(strength.workingSets)"
                    )

                    reportMetric(
                        title: "총 반복",
                        value: "\(strength.totalRepetitions)"
                    )

                    reportMetric(
                        title: "총 볼륨",
                        value: formatNumber(
                            strength.totalVolumeKilograms,
                            suffix: " kg"
                        )
                    )

                    reportMetric(
                        title: "최대 중량",
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
                        title: "평균 휴식",
                        value: strength.averageRestDuration.map(
                            formatDuration
                        ) ?? "-"
                    )
                }

                if !viewModel.strengthSets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("세트 기록")
                            .font(.headline)

                        ForEach(viewModel.strengthSets) { set in
                            strengthSetRow(set)
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
            LazyVGrid(
                columns: gridColumns,
                spacing: 12
            ) {
                reportMetric(
                    title: "거리",
                    value: formatDistance(
                        cardio.distanceMeters
                    )
                )

                reportMetric(
                    title: "평균 페이스",
                    value: formatPace(
                        cardio.averagePaceSecondsPerKilometer
                    )
                )

                reportMetric(
                    title: "평균 속도",
                    value: formatSpeed(
                        cardio.averageSpeedMetersPerSecond
                    )
                )

                reportMetric(
                    title: "최고 속도",
                    value: formatSpeed(
                        cardio.maximumSpeedMetersPerSecond
                    )
                )

                reportMetric(
                    title: "케이던스",
                    value: formatNumber(
                        cardio.averageCadence,
                        suffix: " /min"
                    )
                )

                reportMetric(
                    title: "평균 파워",
                    value: formatNumber(
                        cardio.averagePowerWatts,
                        suffix: " W"
                    )
                )

                reportMetric(
                    title: "고도 상승",
                    value: formatNumber(
                        cardio.elevationGainMeters,
                        suffix: " m"
                    )
                )

                reportMetric(
                    title: "경로 포인트",
                    value: "\(cardio.routePointCount)"
                )
            }
        }
    }

    private var detailsSection: some View {
        reportSection(title: "Details") {
            VStack(spacing: 12) {
                detailRow(
                    title: "전체 경과 시간",
                    value: formatDuration(
                        viewModel.report.summary.elapsedDuration
                    )
                )

                detailRow(
                    title: "일시정지 시간",
                    value: formatDuration(
                        viewModel.report.summary.pausedDuration
                    )
                )

                detailRow(
                    title: "걸음 수",
                    value: formatNumber(
                        viewModel.report.summary.stepCount
                    )
                )

                detailRow(
                    title: "심박 샘플",
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
        let weight = set.weightKilograms.map {
            String(
                format: "%.1f",
                $0
            )
        } ?? "-"

        let repetitions = set.repetitions.map(
            String.init
        ) ?? "-"

        return "\(weight) kg × \(repetitions)"
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
