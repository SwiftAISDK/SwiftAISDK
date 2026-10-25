// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "CompleteConsumer",
    platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [.package(url: "https://github.com/SwiftAISDK/SwiftAISDK.git", from: "3.0.0")],
    targets: [.executableTarget(name: "CompleteConsumer", dependencies: [
        .product(name: "SwiftAISDK", package: "SwiftAISDK")
    ])],
    swiftLanguageModes: [.v6]
)
