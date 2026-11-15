import SwiftAIProvider
import SwiftAIParallel
import SwiftAIScaleDown
import SwiftAITencent
import SwiftAIHeyGen

// Keep the compatibility facade's AIProviders namespace usable when imported
// alongside the independently distributed native provider modules.
public extension AIProviders {
    static func parallel(configuration: ParallelProviderSettings = .init()) -> ParallelProvider {
        ParallelProvider(configuration: configuration)
    }

    static func scaleDown(configuration: ScaleDownProviderSettings = .init()) -> ScaleDownProvider {
        ScaleDownProvider(configuration: configuration)
    }

    static func tencent(configuration: TencentProviderSettings = .init()) -> TencentProvider {
        TencentProvider(configuration: configuration)
    }

    static func heyGen(configuration: HeyGenProviderSettings) throws -> HeyGenProvider {
        try HeyGenProvider(configuration: configuration)
    }
}
