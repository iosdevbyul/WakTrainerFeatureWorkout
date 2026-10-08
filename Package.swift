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
            revision: "a19ca9d53b7b395b3c41efbbcc9883c53a672832"
        ),
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerDomainWorkout",
            revision: "718bb0f176e64820404f6994b53830b48f2cfee7"
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
