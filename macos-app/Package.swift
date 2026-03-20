// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LoopCommander",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LoopCommander", targets: ["LoopCommander"]),
    ],
    targets: [
        .executableTarget(
            name: "LoopCommander",
            path: "LoopCommander"
        ),
    ]
)
