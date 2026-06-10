// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Timely",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Timely", path: "Sources/Timely")
    ]
)
