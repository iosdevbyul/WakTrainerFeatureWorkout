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
