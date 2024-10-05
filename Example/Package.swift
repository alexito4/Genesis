// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Example",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: ".."),
//        .package(url: "https://github.com/alexito4/Genesis.git", branch: "main")
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
