@testable import SwiftAIAnthropic
@testable import SwiftAIOpenAICompatible
@testable import SwiftAIOpenAI
@testable import SwiftAI
@testable import SwiftAITransport
private typealias AI = SwiftAISDK.AI
private typealias AIProviders = SwiftAISDK.AIProviders
private typealias AICustomProvider = SwiftAISDK.AICustomProvider
import Testing
@testable import SwiftAISDK

@Suite(.serialized)
struct AiTelemetryRegistryUpstreamTests {
    @Test func telemetryRegistryAddsSingleIntegrationLikeUpstream() {
        Telemetry.removeAllIntegrations()
        defer { Telemetry.removeAllIntegrations() }

        Telemetry.register(NamedTelemetryIntegration(name: "first"))

        #expect(registeredTelemetryIntegrationNames() == ["first"])
    }

    @Test func telemetryRegistryAddsMultipleIntegrationsInRegistrationOrderLikeUpstream() {
        Telemetry.removeAllIntegrations()
        defer { Telemetry.removeAllIntegrations() }

        Telemetry.register(NamedTelemetryIntegration(name: "first"))
        Telemetry.register(NamedTelemetryIntegration(name: "second"))

        #expect(registeredTelemetryIntegrationNames() == ["first", "second"])
    }

    @Test func telemetryRegistryAddsArrayIntegrationsInOrderLikeUpstream() {
        Telemetry.removeAllIntegrations()
        defer { Telemetry.removeAllIntegrations() }

        Telemetry.register([
            NamedTelemetryIntegration(name: "first"),
            NamedTelemetryIntegration(name: "second")
        ])

        #expect(registeredTelemetryIntegrationNames() == ["first", "second"])
    }

    @Test func telemetryRegistryRegisterNoArgumentsIsNoopLikeUpstream() {
        Telemetry.removeAllIntegrations()
        defer { Telemetry.removeAllIntegrations() }

        Telemetry.register()

        #expect(Telemetry.registeredIntegrations().isEmpty)
    }

    @Test func telemetryRegistryReturnsEmptyArrayWhenNoIntegrationsRegisteredLikeUpstream() {
        Telemetry.removeAllIntegrations()
        defer { Telemetry.removeAllIntegrations() }

        #expect(Telemetry.registeredIntegrations().isEmpty)
    }
}

private struct NamedTelemetryIntegration: Telemetry.Integration {
    var name: String

    func record(_ event: Telemetry.Event) async {}
}

private func registeredTelemetryIntegrationNames() -> [String] {
    Telemetry.registeredIntegrations().compactMap { integration in
        (integration as? NamedTelemetryIntegration)?.name
    }
}
