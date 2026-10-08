# WorkoutFeatureDemo

A standalone iOS demo project for the real `WakTrainerFeatureWorkout` Swift package.

## Run

1. Open `Example/WorkoutFeatureDemo.xcodeproj` in Xcode.
2. Select the shared **WorkoutFeatureDemo** scheme and an iOS 17+ simulator.
3. Run. Tap the **W** launcher to explore quick starts, strength training, session controls and workout reports.
4. Open **Workout History** to inspect persisted completed sessions.

The Xcode project refers to the package in the parent directory (`../`). It uses the repository's real package source and does not duplicate any workout logic.

## Notes

- iOS 17+; test on the iOS simulator or a device with a configured signing team.
- Location and HealthKit behavior depend on simulator/device authorization and available data.
- Completed workouts are stored through the package's existing SwiftData storage.
- No WakTrainerApp, AuthenticationKit, Wi-Fi recognition, or server is required.
- This demo is intended for package interaction testing, not an automated end-to-end proof of hardware features.

## CI

The repository PR workflow builds the demo against an available iOS simulator in addition to its existing library build/tests.
