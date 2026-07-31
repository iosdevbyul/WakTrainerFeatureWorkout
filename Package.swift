// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakTrainerFeatureWorkout",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WakTrainerFeatureWorkout",
            targets: ["WakTrainerFeatureWorkout"]
        ),
    ],
    dependencies: [
        .package(path: "../WakTrainerCoreModels"),
        .package(path: "../WakTrainerCoreServices")
    ],
    targets: [
        .target(
            name: "WakTrainerFeatureWorkout",
            dependencies: [
                .product(name: "WakTrainerCoreModels", package: "WakTrainerCoreModels"),
                .product(name: "WakTrainerCoreServices", package: "WakTrainerCoreServices")
            ]
        ),
        .testTarget(
            name: "WakTrainerFeatureWorkoutTests",
            dependencies: ["WakTrainerFeatureWorkout"]
        ),
    ]
)
