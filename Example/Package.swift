// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Example",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: [
                .product(name: "Genesis", package: "Genesis"),
                .product(name: "GenesisMarkdown", package: "Genesis"),
            ]
        ),
    ]
)
