// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakTrainerFeatureWorkout",
    platforms: [
        .iOS(.v14),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WakTrainerFeatureWorkout", targets: ["WakTrainerFeatureWorkout"])
    ],
    dependencies: [
        .package(url: "https://github.com/iosdevbyul/WakTrainerCoreModels", branch: "main"),
        .package(url: "https://github.com/iosdevbyul/WakTrainerDomainWorkout", branch: "main"),
        .package(url: "https://github.com/iosdevbyul/WakTrainerFeatureTimer", branch: "main")
    ],
    targets: [
        .target(
            name: "WakTrainerFeatureWorkout",
            dependencies: [
                .product(name: "WakTrainerCoreModels", package: "WakTrainerCoreModels"),
                .product(name: "WakTrainerDomainWorkout", package: "WakTrainerDomainWorkout"),
                .product(name: "WakTrainerFeatureTimer", package: "WakTrainerFeatureTimer")
            ]
        )
    ]
)
