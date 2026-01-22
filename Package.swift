// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PromptHoarder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PromptHoarderCore",
            targets: ["PromptHoarderCore"]
        ),
        .executable(
            name: "PromptHoarder",
            targets: ["PromptHoarder"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-markdown", from: "0.5.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        // Core library - shared between GUI and future CLI
        .target(
            name: "PromptHoarderCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // macOS app
        .executableTarget(
            name: "PromptHoarder",
            dependencies: [
                "PromptHoarderCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Core tests
        .testTarget(
            name: "PromptHoarderCoreTests",
            dependencies: ["PromptHoarderCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // App tests
        .testTarget(
            name: "PromptHoarderTests",
            dependencies: ["PromptHoarder"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
