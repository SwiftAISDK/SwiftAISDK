// swift-tools-version: 6.3
import PackageDescription
let package = Package(name: "AnthropicOnly", platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [.package(path: "../../Packages/swift-ai-core"), .package(path: "../../Packages/swift-ai-anthropic")],
    targets: [.executableTarget(name: "ProviderConsumer", dependencies: [.product(name: "SwiftAI", package: "swift-ai-core"), .product(name: "SwiftAITransport", package: "swift-ai-core"), .product(name: "SwiftAIAnthropic", package: "swift-ai-anthropic")])],
    swiftLanguageModes: [.v6]
)
