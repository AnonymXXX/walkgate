// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "WalkGate",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "WalkGate", targets: ["WalkGate"]),
    .library(name: "WalkGateCore", targets: ["WalkGateCore"]),
  ],
  targets: [
    .target(name: "WalkGateCore"),
    .executableTarget(
      name: "WalkGate",
      dependencies: ["WalkGateCore"]
    ),
    .testTarget(
      name: "WalkGateCoreTests",
      dependencies: ["WalkGateCore"]
    ),
  ]
)
