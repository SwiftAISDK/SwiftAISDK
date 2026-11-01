import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAICompatible

private actor WeeklyCompatibleKeys {
    var count = 0
    func next() -> String { count += 1; return "key-\(count)" }
}

@Suite struct Weekly20261101CompatibleTests {
    @Test func mapsOnlyPortableReasoningAndPreservesExplicitProviderValue() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let http = AIProviderHTTPClient(providerID: "custom.chat", transport: transport, url: { _, _ in URL(string: "https://example.com/chat")! })
        var configuration = OpenAICompatibleModelConfiguration(http: http, baseURL: "https://example.com")
        configuration.mapReasoning = { reasoning, _, warnings in warnings.append(.init(type: "compatibility", feature: "reasoning")); return "mapped-" + reasoning }
        let model = OpenAICompatibleChatModel(modelID: "model", config: configuration)
        let first = try await model.generate(.init(messages: [.user("Hi")], reasoning: "xhigh"))
        let second = try await model.generate(.init(messages: [.user("Hi")], reasoning: "medium", providerOptions: ["custom": ["reasoningEffort": "max"]]))
        let requests = await transport.requests()
        #expect(try decodeJSONBody(#require(requests[0].body))["reasoning_effort"] == "mapped-xhigh")
        #expect(try decodeJSONBody(#require(requests[1].body))["reasoning_effort"] == "max")
        #expect(first.warnings.contains { $0.type == "compatibility" })
        #expect(second.warnings.isEmpty)
    }

    @Test func keySupplierRunsForEachRequest() async throws {
        let keys = WeeklyCompatibleKeys()
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"done"},"finish_reason":"stop"}]}"#))
        let provider = OpenAICompatibleProvider(configuration: .init(name: "custom", baseURL: "https://example.com", transport: transport, apiKeyProvider: { await keys.next() }))
        for _ in 0..<2 { _ = try await provider.chatModel("model").generate(.init(messages: [.user("Hi")])) }
        #expect(await transport.requests().map { $0.headers.first { $0.key.lowercased() == "authorization" }?.value } == ["Bearer key-1", "Bearer key-2"])
    }

    @Test func misplacedSystemErrorContainsTheContent() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = OpenAICompatibleProvider(configuration: .init(name: "custom", baseURL: "https://example.com", transport: transport))
        let model = try provider.completionModel("model")
        do { _ = try await model.generate(.init(messages: [.user("Hi"), .system("misplaced")]))
            Issue.record("Expected invalid prompt")
        } catch { #expect(String(describing: error).contains("Unexpected system message in prompt: misplaced")) }
        #expect(await transport.requests().isEmpty)
    }
}
