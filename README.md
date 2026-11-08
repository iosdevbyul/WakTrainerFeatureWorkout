# WakTrainerFeatureWorkout

`WakTrainerFeatureWorkout` owns the complete workout experience from launch to report.

## Flow

```text
Floating Workout Orb
→ Quick workout menu
→ Workout selection
→ Workout session
→ Pause / Resume
→ Workout finish
→ WorkoutSession
→ Workout Report
```

The host application does not need to build its own workout-start button or workout flow.

## Floating launcher

The package provides a reusable floating launcher view.

```swift
WorkoutLauncherView(
    maximumHeartRate: maximumHeartRate
) { session in
    // Persist or upload the completed WorkoutSession.
}
```

The launcher owns:

- the floating `W` orb
- expand / close state
- running
- walking
- indoor and outdoor cycling
- strength-workout selection
- full-screen workout presentation
- workout completion
- Workout Report presentation

## View modifier

A host can also attach the launcher directly to an existing root view.

```swift
MainContentView()
    .wakTrainerWorkoutLauncher(
        maximumHeartRate: maximumHeartRate
    ) { session in
        // Persist or upload the completed WorkoutSession.
    }
```

`bottomPadding` can be adjusted by the host when the launcher needs to sit above a custom tab bar.

## Existing workout feature

`WorkoutFeatureView` remains available when a host wants to present the workout flow directly without the floating launcher.

```swift
WorkoutFeatureView(
    maximumHeartRate: maximumHeartRate
) { session in
    // Handle the completed WorkoutSession.
}
```

## Ownership boundary

`WakTrainerFeatureWorkout` owns workout UI and workout flow. The host application only decides where the launcher is placed and what to do with the completed `WorkoutSession`.

## Explicit TrisDashboard workout JSON export

The `WorkoutHistoryStore.dashboardExportV2()` API converts **already loaded, completed and owner-scoped** workout history into the version 2 TrisDashboard JSON contract. Each exported workout uses its persisted UUID as the stable session ID, a UTC source timestamp, active workout duration in seconds and the health summary's distance in meters (default 0 if absent). Route points, HR traces and user profile identifiers are deliberately excluded. Invalid durations, distances, unsupported workout IDs and exports exceeding 500 sessions/128 KiB cause an error instead of silently dropping records. Call `await store.reload()` before exporting to get the latest persisted history; exporting does not share or transmit data. The WakTrainerApp user-facing share action is tracked separately.
