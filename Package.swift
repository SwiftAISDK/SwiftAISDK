// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAISDK",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftAISDK",
            targets: ["SwiftAISDK"]
        ),
    ],
    dependencies: [.package(path: "Packages/swift-ai-core"), .package(path: "Packages/swift-ai-anthropic"), .package(path: "Packages/swift-ai-openai-compatible"), .package(path: "Packages/swift-ai-openai")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftAISDK",
            dependencies: [.product(name: "SwiftAIOpenAI", package: "swift-ai-openai"), .product(name: "SwiftAIOpenAICompatible", package: "swift-ai-openai-compatible"), .product(name: "SwiftAIAnthropic", package: "swift-ai-anthropic"), .product(name: "SwiftAI", package: "swift-ai-core"), .product(name: "SwiftAIProvider", package: "swift-ai-core"), .product(name: "SwiftAITransport", package: "swift-ai-core"), .product(name: "SwiftAIProviderUtilities", package: "swift-ai-core")]
        ),
        .testTarget(
            name: "SwiftAISDKTests",
            dependencies: ["SwiftAISDK", .product(name: "SwiftAI", package: "swift-ai-core"), .product(name: "SwiftAIProvider", package: "swift-ai-core"), .product(name: "SwiftAITransport", package: "swift-ai-core"), .product(name: "SwiftAIProviderUtilities", package: "swift-ai-core")],
            resources: [.process("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
