import SwiftUI
import MapKit
import UIKit
import WakTrainerCoreModels
import WakTrainerDomainWorkout
import WakTrainerFeatureTimer
import WakTrainerServiceLocation
import WakTrainerServiceWorkoutStorage

@MainActor
struct WorkoutSessionView: View {

    @StateObject private var viewModel:
        WorkoutSessionViewModel
    @State private var isExercisePickerPresented =
        false
    @State private var didPresentInitialExercisePicker = false
    @State private var isFullScreenMapPresented = false
    @State private var workoutMapMode: WorkoutMapMode = .twoD
    @State private var workoutMapCamera: MapCameraPosition = .automatic
    @State private var pendingWorkoutAction: WorkoutActionConfirmation?

    private enum WorkoutActionConfirmation: String, Identifiable {
        case pause
        case finish
        var id: String { rawValue }
    }

    private let strengthLocationPolicy: StrengthWorkoutLocationPolicy
    private let maximumHeartRate: Double?
    private let weightUnit: WorkoutWeightUnit
    private let workout:
        WorkoutDefinition
    private let fetchStrengthExercisesUseCase:
        FetchStrengthExercisesUseCase
    private let onCancel: () -> Void
    private let onFinished:
        (WorkoutSession) -> Void
    private let onWorkoutUpdate: ((WorkoutLiveSnapshot) -> Void)?

    init(
        workout: WorkoutDefinition,
        restoredSession:
            StoredWorkoutSession? = nil,
        sessionRepository:
            (any WorkoutSessionRepository)? = nil,
        weightUnit: WorkoutWeightUnit = .kg,
        maximumHeartRate: Double? = nil,
        strengthLocationPolicy: StrengthWorkoutLocationPolicy = .singleLocation,
        onCancel:
            @escaping () -> Void,
        onFinished:
            @escaping (WorkoutSession) -> Void,
        onWorkoutUpdate: ((WorkoutLiveSnapshot) -> Void)? = nil
    ) {
        self.workout = workout
        self.weightUnit = weightUnit
        self.maximumHeartRate = maximumHeartRate
        self.strengthLocationPolicy = strengthLocationPolicy
        self.onCancel = onCancel
        self.onFinished = onFinished
        self.onWorkoutUpdate = onWorkoutUpdate

        let resolvedRepository =
            sessionRepository
            ?? (
                try?
                SwiftDataWorkoutSessionRepository()
            )

        let strengthRepository =
            LocalStrengthExerciseCatalogRepository()

        self.fetchStrengthExercisesUseCase =
            FetchStrengthExercisesUseCase(
                repository:
                    strengthRepository
            )

        _viewModel = StateObject(
            wrappedValue:
                WorkoutSessionViewModel(
                    workout: workout,
                    restoredSession:
                        restoredSession,
                    strengthLocationPolicy: strengthLocationPolicy,
                    sessionRepository:
                        resolvedRepository
                )
        )
    }

    var body: some View {
        ZStack {
            sessionBackground

            if workout.category
                == .strength {
                strengthSessionContent
            } else {
                cardioSessionContent
            }
        }
        .onChange(of: liveSnapshot, initial: true) { _, snapshot in
            if let snapshot { onWorkoutUpdate?(snapshot) }
        }
        .toolbar {
            if viewModel.timerState
                == .idle {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button("Back") {
                        onCancel()
                    }
                }
            }
        }
        .onAppear {
            viewModel.onLiveMetricsUpdated = { [weak viewModel] in
                guard let viewModel, viewModel.timerState != .idle else { return }
                let completed = viewModel.completedStrengthExerciseRecords.reduce(0) {
                    $0 + $1.strengthSets.filter(\.isCompleted).count
                } + viewModel.strengthSets.filter(\.isCompleted).count
                onWorkoutUpdate?(WorkoutLiveSnapshot(
                    kind: workout.category == .strength ? .strength : .cardio,
                    phase: viewModel.timerState == .running ? .running : .paused,
                    workoutName: workout.name,
                    elapsedSeconds: viewModel.elapsedTime,
                    heartRateBPM: viewModel.heartRate,
                    activeCalories: viewModel.activeCalories,
                    distanceMeters: viewModel.distanceMeters,
                    steps: viewModel.stepCount,
                    currentExerciseName: viewModel.activeStrengthExercise?.name,
                    completedSets: completed
                ))
            }
            viewModel.resumeRecoveredWorkoutIfNeeded()
            guard workout.category == .strength,
                  viewModel.timerState == .idle,
                  viewModel.activeStrengthExercise == nil,
                  !didPresentInitialExercisePicker else { return }
            didPresentInitialExercisePicker = true
            isExercisePickerPresented = true
        }
        .confirmationDialog(
            "Confirm Workout Action",
            isPresented: Binding(
                get: { pendingWorkoutAction != nil },
                set: { if !$0 { pendingWorkoutAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if pendingWorkoutAction == .pause {
                Button("Pause Workout") {
                    pendingWorkoutAction = nil
                    viewModel.pauseWorkout()
                }
            } else if pendingWorkoutAction == .finish {
                Button("Finish Workout", role: .destructive) {
                    pendingWorkoutAction = nil
                    Task { await finishCurrentWorkout() }
                }
            }
            Button("Keep Exercising", role: .cancel) {
                pendingWorkoutAction = nil
            }
        } message: {
            Text(pendingWorkoutAction == .pause
                ? "Pause the current workout?"
                : "End this workout and save its report?")
        }
        .sheet(
            isPresented:
                $isExercisePickerPresented
        ) {
            StrengthExerciseSelectionView(
                fetchExercisesUseCase:
                    fetchStrengthExercisesUseCase,
                onCancel: {
                    isExercisePickerPresented =
                        false
                },
                onSelected: {
                    exercise,
                    equipment in

                    _ = viewModel.beginStrengthExercise(
                        exercise,
                        equipment: equipment
                    )
                    isExercisePickerPresented = false
                    // Selecting an exercise should never start recording.
                }
            )
        }
    }

    private var liveSnapshot: WorkoutLiveSnapshot? {
        guard viewModel.timerState != .idle else { return nil }
        let completed = viewModel.completedStrengthExerciseRecords.reduce(0) {
            $0 + $1.strengthSets.filter(\.isCompleted).count
        } + viewModel.strengthSets.filter(\.isCompleted).count
        return WorkoutLiveSnapshot(
            kind: workout.category == .strength ? .strength : .cardio,
            phase: viewModel.timerState == .running ? .running : .paused,
            workoutName: workout.name,
            elapsedSeconds: viewModel.elapsedTime,
            heartRateBPM: viewModel.heartRate,
            activeCalories: viewModel.activeCalories,
            distanceMeters: viewModel.distanceMeters,
            steps: viewModel.stepCount,
            currentExerciseName: viewModel.activeStrengthExercise?.name,
            completedSets: completed
        )
    }

    // MARK: - Shared Header

    private var header:
        some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(workout.name)
                    .font(.headline)

                CapsuleTimerView(
                    timerManager:
                        viewModel
                            .timerManager,
                    textColor: .black
                )
            }

            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Cardio

    private var cardioSessionContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 6) {
                header
                controlButtons
                    .padding(.horizontal, 20)

                if workout.requiresLocationTracking {
                    WorkoutMapView(
                        workoutType: workout.type,
                        paceSegments: currentPaceSegments,
                        followsCurrentPosition: true
                    )
                    .frame(height: max(90, min(geometry.size.height * 0.22, 160)))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            isFullScreenMapPresented = true
                        } label: {
                            Label("Expand Map", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.bold())
                                .padding(10)
                                .background(.regularMaterial, in: Capsule())
                        }
                        .padding(10)
                    }
                    .padding(.horizontal, 20)
                    .onTapGesture { isFullScreenMapPresented = true }
                }

                WorkoutTrackerView(viewModel: viewModel, compact: true, maximumHeartRate: maximumHeartRate)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            }
            // Without an explicit alignment, the VStack's intrinsic content
            // is centered vertically in the GeometryReader's full height.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(isPresented: $isFullScreenMapPresented) {
            NavigationStack {
                ZStack(alignment: .bottom) {
                    Map(position: $workoutMapCamera) {
                        if viewModel.routeCoordinates.count >= 2 {
                            MapPolyline(coordinates: viewModel.routeCoordinates)
                                .stroke(.green, lineWidth: 5)
                        }
                        if let current = viewModel.routeCoordinates.last {
                            Annotation("Current", coordinate: current, anchor: .center) {
                                Image(systemName: "location.north.circle.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.green)
                                    .rotationEffect(.degrees(workoutHeading))
                            }
                        }
                    }
                    .mapStyle(workoutMapStyle)
                    .mapControls {
                        MapCompass()
                        MapPitchToggle()
                    }
                    .ignoresSafeArea(edges: .bottom)

                    if workoutMapMode == .runner {
                        Image(systemName: "figure.run")
                            .font(.system(size: 58, weight: .medium))
                            .foregroundStyle(.green)
                            .shadow(color: .black, radius: 5)
                            .padding(.bottom, 110)
                            .allowsHitTesting(false)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Picker("Map Mode", selection: $workoutMapMode) {
                        ForEach(WorkoutMapMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .accessibilityIdentifier("workout.map.mode")
                }
                .navigationTitle("Workout Map")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isFullScreenMapPresented = false }
                    }
                }
                .onAppear { updateWorkoutMapCamera() }
                .onChange(of: workoutMapMode) { _, _ in updateWorkoutMapCamera() }
                .onChange(of: viewModel.routeCoordinates.count) { _, _ in
                    updateWorkoutMapCamera()
                }
            }
        }
    }

    private enum WorkoutMapMode: String, CaseIterable, Identifiable {
        case twoD = "2D"
        case follow = "3D Follow"
        case aerial = "3D Aerial"
        case runner = "Runner View"
        var id: Self { self }
    }

    private var workoutMapStyle: MapStyle {
        switch workoutMapMode {
        case .twoD: .standard(elevation: .flat)
        case .follow, .runner: .standard(elevation: .realistic)
        case .aerial: .imagery(elevation: .realistic)
        }
    }

    private var workoutHeading: Double {
        let points = viewModel.routeCoordinates
        guard points.count >= 2 else { return 0 }
        let first = points[points.count - 2]
        let last = points[points.count - 1]
        let latitude1 = first.latitude * .pi / 180
        let latitude2 = last.latitude * .pi / 180
        let longitudeDifference = (last.longitude - first.longitude) * .pi / 180
        let y = sin(longitudeDifference) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2) -
            sin(latitude1) * cos(latitude2) * cos(longitudeDifference)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func updateWorkoutMapCamera() {
        guard let current = viewModel.routeCoordinates.last else { return }
        let heading = workoutMapMode == .twoD ? 0 : workoutHeading
        let pitch: Double = workoutMapMode == .twoD ? 0 :
            (workoutMapMode == .runner ? 72 : 55)
        workoutMapCamera = .camera(MapCamera(
            centerCoordinate: current,
            distance: workoutMapMode == .runner ? 95 : 350,
            heading: heading,
            pitch: pitch
        ))
    }

    // MARK: - Strength

    private var strengthSessionContent:
        some View {
        VStack(spacing: 0) {
            header
            controlButtons
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 16) {
                    if let activeExercise =
                            viewModel
                                .activeStrengthExercise {
                        activeExerciseCard(
                            activeExercise
                        )
                    } else {
                        chooseExerciseCard
                    }

                    if viewModel.timerState
                        != .idle,
                       viewModel
                        .activeStrengthExercise
                        != nil,
                       viewModel
                        .activeStrengthEquipment
                        != nil {
                        StrengthSetRecorderView(
                            viewModel:
                                viewModel,
                            weightUnit: weightUnit
                        )
                    }

                    if !viewModel.completedStrengthExerciseRecords.isEmpty {
                        completedExercisesCard
                    }

                    WorkoutTrackerView(
                        viewModel: viewModel,
                        maximumHeartRate: maximumHeartRate
                    )

                    if viewModel.timerState
                        != .idle {
                        Button {
                            isExercisePickerPresented =
                                true
                        } label: {
                            Label(
                                "Add Exercise",
                                systemImage:
                                    "plus.circle.fill"
                            )
                            .font(.headline)
                            .frame(
                                maxWidth:
                                    .infinity
                            )
                            .padding(
                                .vertical,
                                12
                            )
                        }
                        .buttonStyle(
                            .bordered
                        )
                        .buttonBorderShape(
                            .roundedRectangle(
                                radius: 16
                            )
                        )
                    }

                }
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .top,
                    20
                )
                .padding(
                    .bottom,
                    24
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            )
        }
    }

    private var chooseExerciseCard:
        some View {
        Button {
            isExercisePickerPresented =
                true
        } label: {
            VStack(spacing: 10) {
                Image(
                    systemName:
                        "figure.strengthtraining.traditional"
                )
                .font(
                    .system(
                        size: 28,
                        weight: .semibold
                    )
                )

                Text(
                    "Choose Exercise"
                )
                .font(.headline)

                Text(
                    "Select an exercise and equipment to begin."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                maxWidth: .infinity
            )
            .padding(20)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(
            .roundedRectangle(
                radius: 18
            )
        )
    }

    private func activeExerciseCard(
        _ exercise:
            StrengthExerciseDefinition
    ) -> some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(exercise.name)
                    .font(.headline)

                if let equipment =
                        viewModel
                            .activeStrengthEquipment {
                    Text(
                        equipment
                            .displayName
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                } else {
                    Text(
                        "Choose Equipment"
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                }

                if !viewModel
                    .strengthSets
                    .isEmpty {
                    Text(
                        "\(viewModel.strengthSets.count) completed sets"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Button(
                viewModel.timerState
                    == .idle
                    ? "Change"
                    : "Switch"
            ) {
                isExercisePickerPresented =
                    true
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var completedExercisesCard:
        some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Switch Exercise")
                .font(.headline)

            Text("Alternate between exercises without losing completed sets.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(
                viewModel
                    .completedStrengthExerciseRecords
            ) { record in
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(record.name)
                            .font(
                                .subheadline
                            )
                            .fontWeight(
                                .semibold
                            )

                        HStack(spacing: 6) {
                            if let equipment =
                                    record
                                        .strengthEquipment {
                                Text(
                                    equipment
                                        .displayName
                                )
                            }

                            Text(
                                "\(record.strengthSets.count) sets"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    if let exerciseID = record.exerciseID,
                       let equipment = record.strengthEquipment {
                        Button {
                            guard viewModel.timerState != .idle else { return }
                            let definition = StrengthExerciseDefinition(
                                id: exerciseID,
                                name: record.name,
                                supportedEquipment: [equipment]
                            )
                            _ = viewModel.beginStrengthExercise(definition, equipment: equipment)
                        } label: {
                            Label("Switch", systemImage: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.timerState == .idle)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    // MARK: - Background

    private var sessionBackground: some View {
        Color.clear.ignoresSafeArea()
    }

    // MARK: - Controls

    private var controlButtons:
        some View {
        HStack(spacing: 12) {
            if viewModel.timerState
                == .idle {
                Button {
                    Task {
                        await viewModel
                            .startWorkout()
                    }
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(
                            .white
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .padding()
                        .background(
                            viewModel
                                .canStartWorkout
                            ? Color.blue
                            : Color.gray
                        )
                        .cornerRadius(14)
                }
                .disabled(
                    !viewModel
                        .canStartWorkout
                )
            } else {
                Button {
                    if viewModel.timerState == .running {
                        pendingWorkoutAction = .pause
                    } else {
                        viewModel.resumeWorkout()
                    }
                } label: {
                    Text(
                        viewModel
                            .timerState
                            == .running
                        ? "Pause"
                        : "Resume"
                    )
                    .font(.headline)
                    .foregroundColor(
                        .white
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding()
                    .background(
                        viewModel
                            .timerState
                            == .running
                        ? Color.orange
                        : Color.green
                    )
                    .cornerRadius(14)
                }

                Button {
                    pendingWorkoutAction = .finish
                } label: {
                    Text(
                        "Finish Workout"
                    )
                    .font(.headline)
                    .foregroundColor(
                        .white
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding()
                    .background(
                        Color.red
                    )
                    .cornerRadius(14)
                }
            }
        }
    }

    private func finishCurrentWorkout() async {
        let session = await viewModel.finishWorkout()
        onWorkoutUpdate?(
            WorkoutLiveSnapshot(
                kind: workout.category == .strength ? .strength : .cardio,
                phase: .finished,
                workoutName: workout.name,
                elapsedSeconds: session.timing.activeDuration,
                heartRateBPM: viewModel.heartRate,
                activeCalories: viewModel.activeCalories,
                distanceMeters: viewModel.distanceMeters,
                steps: viewModel.stepCount,
                currentExerciseName: viewModel.activeStrengthExercise?.name,
                completedSets: viewModel.strengthSets.count
            )
        )
        onFinished(session)
    }

    // MARK: - Route

    private var currentPaceSegments:
        [PaceSegment] {
        let coordinates =
            viewModel
                .routeCoordinates

        guard coordinates.count
            >= 2 else {
            return []
        }

        return (
            0..<(coordinates.count - 1)
        ).map { index in
            PaceSegment(
                startCoordinate:
                    coordinates[index],
                endCoordinate:
                    coordinates[
                        index + 1
                    ],
                speedCategory:
                    .moderate,
                speedMs: 2.5
            )
        }
    }
}
