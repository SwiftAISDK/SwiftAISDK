import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIFireworks

@Suite struct Weekly20261101FireworksBehaviorTests {
    @Test(arguments: [("test-model", "max", "max"), ("test-model", "minimal", "minimal"), ("accounts/fireworks/models/gpt-oss-120b", "none", "minimal"), ("accounts/fireworks/routers/glm-5p3-fast", "none", "minimal"), ("accounts/fireworks/models/muse-spark-open", "none", "minimal"), ("accounts/fireworks/models/nemotron-3-ultra-nvfp4", "minimal", "low"), ("accounts/fireworks/models/inkling", "minimal", "low")], [false, true])
    func portableEffortUsesModelSpecificExclusions(_ fixture: (String, String, String), _ streaming: Bool) async throws {
        let raw = #"{"choices":[{"message":{"content":"done"},"delta":{"content":"done"},"finish_reason":"stop"}]}"#
        let transport = RecordingTransport(response: streaming ? sseResponse("data: " + raw) : jsonResponse(raw))
        let model = try FireworksProvider(configuration: .init(apiKey: "key", transport: transport)).languageModel(fixture.0)
        let request = LanguageModelRequest(messages: [.user("Hi")], reasoning: fixture.1)
        var warnings: [AIWarning] = []
        if streaming { for try await part in model.stream(request) { if case let .streamStart(value) = part { warnings = value } } }
        else { warnings = try await model.generate(request).warnings }
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning_effort"] == .string(fixture.2))
        #expect(warnings.contains { $0.type == "compatibility" && $0.feature == "reasoning" } == (fixture.1 != fixture.2))
    }

    @Test func explicitProviderAndRawBodyEffortsBypassPortableMapping() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let model = try FireworksProvider(configuration: .init(apiKey: "key", transport: transport)).languageModel("accounts/fireworks/models/nemotron-3")
        let result = try await model.generate(.init(messages: [.user("Hi")], reasoning: "max", providerOptions: ["fireworks": ["reasoningEffort": "minimal"]]))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning_effort"] == "minimal")
        #expect(result.warnings.isEmpty)
        #expect(fireworksChatBody(from: ["reasoning_effort": "xhigh"])["reasoning_effort"] == "xhigh")
    }
}
