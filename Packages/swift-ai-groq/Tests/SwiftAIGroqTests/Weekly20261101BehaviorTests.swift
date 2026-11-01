import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIGroq

@Suite struct Weekly20261101GroqBehaviorTests {
    @Test(arguments: [("openai/gpt-oss-120b", "low"), ("qwen/qwen3.6-27b", "none"), ("llama-3.3-70b-versatile", "")], [false, true])
    func noneDependsOnTheModelFamily(_ fixture: (String, String), _ streaming: Bool) async throws {
        let raw = #"{"choices":[{"message":{"content":"done"},"delta":{"content":"done"},"finish_reason":"stop"}]}"#
        let transport = RecordingTransport(response: streaming ? sseResponse("data: " + raw) : jsonResponse(raw))
        let model = try GroqProvider(configuration: .init(apiKey: "key", transport: transport)).languageModel(fixture.0)
        let request = LanguageModelRequest(messages: [.user("Hi")], reasoning: "none")
        var warnings: [AIWarning] = []
        if streaming { for try await part in model.stream(request) { if case let .streamStart(value) = part { warnings = value } } }
        else { warnings = try await model.generate(request).warnings }
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["reasoning_effort"]?.stringValue == (fixture.1.isEmpty ? nil : fixture.1))
        #expect(warnings.contains { $0.type == (fixture.1.isEmpty ? "unsupported" : "compatibility") && $0.feature == "reasoning" } == (fixture.1 != "none"))
    }
}
