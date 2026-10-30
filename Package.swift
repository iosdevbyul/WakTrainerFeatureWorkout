// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakTrainerFeatureWorkout",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "WakTrainerFeatureWorkout", targets: ["WakTrainerFeatureWorkout"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerCoreModels",
            branch: "main"
        ),
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerDomainWorkout",
            branch: "main"
        ),
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerFeatureTimer",
            revision: "46a6adc65b69ef3f966448d7f26084fe3dee68d7"
        ),
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerServiceLocation",
            branch: "main"
        ),
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerServiceHealthKit",
            branch: "main"
        ),
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerServiceWorkoutStorage",
            branch: "main"
        ),
        .package(
            url: "https://github.com/iosdevbyul/TrisMotionKit",
            revision: "5b1b18e7a2da3b827a1991f59a40c861c2debc5c"
        )
    ],
    targets: [
        .target(
            name: "WakTrainerFeatureWorkout",
            dependencies: [
                .product(
                    name: "WakTrainerCoreModels",
                    package: "WakTrainerCoreModels"
                ),
                .product(
                    name: "WakTrainerDomainWorkout",
                    package: "WakTrainerDomainWorkout"
                ),
                .product(
                    name: "WakTrainerFeatureTimer",
                    package: "WakTrainerFeatureTimer"
                ),
                .product(
                    name: "WakTrainerServiceLocation",
                    package: "WakTrainerServiceLocation"
                ),
                .product(
                    name: "WakTrainerServiceHealthKit",
                    package: "WakTrainerServiceHealthKit"
                ),
                .product(
                    name: "WakTrainerServiceWorkoutStorage",
                    package: "WakTrainerServiceWorkoutStorage"
                ),
                .product(
                    name: "TrisMotionKit",
                    package: "TrisMotionKit"
                )
            ]
        ),
        .testTarget(
            name: "WakTrainerFeatureWorkoutTests",
            dependencies: [
                "WakTrainerFeatureWorkout"
            ]
        )
    ]
)
