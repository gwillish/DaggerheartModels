// swift-tools-version: 6.2

import PackageDescription

let sharedSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "DaggerheartModels",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .tvOS(.v17),
    .watchOS(.v10),
  ],
  products: [
    .library(name: "DaggerheartModels", targets: ["DaggerheartModels"]),
    .library(name: "DaggerheartKit", targets: ["DaggerheartKit"]),
    .executable(name: "validate-dhpack", targets: ["validate-dhpack"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
  ],
  targets: [
    // Pure Codable value types — no Apple-only imports, compiles on Linux.
    .target(
      name: "DaggerheartModels",
      swiftSettings: sharedSettings
    ),

    // Observable stores + SRD bundle resources — Apple platforms only.
    .target(
      name: "DaggerheartKit",
      dependencies: [
        "DaggerheartModels",
        .product(name: "Logging", package: "swift-log"),
      ],
      resources: [
        .copy("Resources/adversaries.json"),
        .copy("Resources/environments.json"),
      ],
      swiftSettings: sharedSettings + [.defaultIsolation(MainActor.self)]
    ),

    // CLI tool for validating .dhpack files — depends only on DaggerheartModels.
    .executableTarget(
      name: "validate-dhpack",
      dependencies: ["DaggerheartModels"],
      swiftSettings: sharedSettings
    ),

    // Tests for DaggerheartModels — run on Linux in CI.
    .testTarget(
      name: "DaggerheartModelsTests",
      dependencies: ["DaggerheartModels"],
      resources: [.copy("Fixtures")],
      swiftSettings: sharedSettings
    ),

    // Tests for DaggerheartKit — Apple platforms only.
    .testTarget(
      name: "DaggerheartKitTests",
      dependencies: ["DaggerheartKit"],
      swiftSettings: sharedSettings + [.defaultIsolation(MainActor.self)]
    ),
  ]
)
