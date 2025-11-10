// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "activitywatch-mcp-server",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "activitywatch", targets: ["ActivityWatchMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
        .package(url: "git@github.com:doozMen/SwiftDateParser.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "ActivityWatchMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "SwiftDateParser", package: "SwiftDateParser"),
            ]
        ),
        .testTarget(
            name: "ActivityWatchMCPTests",
            dependencies: [
                "ActivityWatchMCP",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
    ]
)
