// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Miorbi",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Miorbi", targets: ["Miorbi"])],
    targets: [
        .executableTarget(name: "Miorbi", path: "Sources/Miorbi", resources: [.process("Resources")]),
        .testTarget(name: "MiorbiTests", dependencies: ["Miorbi"], path: "Tests/MiorbiTests")
    ]
)
