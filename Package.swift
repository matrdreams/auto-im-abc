// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "auto-im-abc",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "auto-im-abc", targets: ["auto-im-abc"])
    ],
    targets: [
        .executableTarget(
            name: "auto-im-abc",
            path: "Sources/auto-im-abc"
        )
    ]
)
