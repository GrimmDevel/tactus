// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tactus",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Tactus",
            path: "Sources/Tactus"
        )
    ]
)
