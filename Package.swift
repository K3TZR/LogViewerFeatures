// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "LogViewerFeatures",
  platforms: [
    .macOS(.v13),
  ],
  
  products: [
    .library(name: "LogView", targets: ["LogView"]),
  ],
  
  dependencies: [
    // ----- K3TZR -----
    .package(url: "https://github.com/K3TZR/ApiFeatures.git", branch: "main"),
    // ----- OTHER -----
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
  ],
  
  // --------------- Modules ---------------
  targets: [
    // LogView
    .target(name: "LogView",
            dependencies: [
              .product(name: "FlexApi", package: "ApiFeatures"),
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]),
  ]
)
