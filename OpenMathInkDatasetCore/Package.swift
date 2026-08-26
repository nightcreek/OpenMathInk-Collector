// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenMathInkDatasetCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "OpenMathInkDatasetCore", targets: ["OpenMathInkDatasetCore"])
    ],
    targets: [
        .target(
            name: "OpenMathInkDatasetCore",
            path: "Sources/OpenMathInkDatasetCore"
        ),
        .testTarget(
            name: "OpenMathInkDatasetCoreTests",
            dependencies: ["OpenMathInkDatasetCore"],
            path: "Tests/OpenMathInkDatasetCoreTests"
        )
    ]
)
