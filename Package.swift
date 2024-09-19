// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Genesis",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Genesis",
            targets: ["Genesis"]
        ),
        .library(
            name: "GenesisMarkdown",
            targets: ["GenesisMarkdown"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Genesis",
            dependencies: []
        ),
        .testTarget(
            name: "GenesisTests",
            dependencies: ["Genesis"]
        ),
        .target(
            name: "GenesisMarkdown",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
    ]
)
