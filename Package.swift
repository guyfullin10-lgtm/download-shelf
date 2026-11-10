// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DownloadShelf",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DownloadShelf",
            path: "Sources/DownloadShelf",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
