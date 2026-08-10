// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakTrainerFeatureWorkout",
    platforms: [
        .iOS(.v13),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WakTrainerFeatureWorkout", targets: ["WakTrainerFeatureWorkout"])
    ],
    dependencies: [
        .package(path: "../WakTrainerCoreModels"),
        .package(path: "../WakTrainerDomainWorkout"),
        .package(path: "../WakTrainerFeatureTimer")
    ],
    targets: [
        .target(
            name: "WakTrainerFeatureWorkout",
            dependencies: [
                "WakTrainerCoreModels",
                "WakTrainerDomainWorkout",
                "WakTrainerFeatureTimer"
            ]
        )
    ]
)
