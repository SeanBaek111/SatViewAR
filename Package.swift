// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SatViewAROrbit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SatViewAROrbit", targets: ["SatViewAROrbit"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/gavineadie/SatelliteKit.git",
            exact: "2.1.2"
        )
    ],
    targets: [
        .target(
            name: "SatViewAROrbit",
            dependencies: [
                .product(name: "SatelliteKit", package: "SatelliteKit")
            ]
        ),
        .testTarget(
            name: "SatViewAROrbitTests",
            dependencies: ["SatViewAROrbit"],
            resources: [.process("Fixtures")]
        )
    ]
)
