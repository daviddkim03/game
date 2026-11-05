// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SystemCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "SystemCore", targets: ["SystemCore"])],
    targets: [
        .target(name: "SystemCore"),
        .testTarget(
            name: "SystemCoreTests",
            dependencies: ["SystemCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
