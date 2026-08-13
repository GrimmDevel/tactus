// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TapticScroll",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "TapticScroll",
            path: "Sources/TapticScroll"
        )
    ]
)
