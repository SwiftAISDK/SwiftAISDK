// swift-tools-version: 6.3
import PackageDescription
let package = Package(name: "OpenAIOnly", platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [.package(path: "../../Packages/swift-ai-core"), .package(path: "../../Packages/swift-ai-openai")],
    targets: [.executableTarget(name: "ProviderConsumer", dependencies: [.product(name: "SwiftAI", package: "swift-ai-core"), .product(name: "SwiftAITransport", package: "swift-ai-core"), .product(name: "SwiftAIOpenAI", package: "swift-ai-openai")])],
    swiftLanguageModes: [.v6]
)
