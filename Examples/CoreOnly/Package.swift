// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "CoreConsumer",
    platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [.package(path: "../../Packages/swift-ai-core")],
    targets: [.executableTarget(name: "CoreConsumer", dependencies: [
        .product(name: "SwiftAI", package: "swift-ai-core")
    ])],
    swiftLanguageModes: [.v6]
)
