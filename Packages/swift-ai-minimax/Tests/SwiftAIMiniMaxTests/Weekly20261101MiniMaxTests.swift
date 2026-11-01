import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIMiniMax

private actor WeeklyMiniMaxTokens {
    var calls = 0
    func next() -> String { calls += 1; return "key-\(calls)" }
}

@Suite struct Weekly20261101MiniMax {
    @Test func callbackIsLazyAndRefreshesEveryMessagesRequest() async throws {
        let tokens = WeeklyMiniMaxTokens()
        let transport = RecordingTransport(response: jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
        let provider = try MiniMaxProvider(settings: .init(environment: [:], transport: transport, apiKeyProvider: { await tokens.next() }))
        let model = try provider.languageModel("minimax-m3.1")
        #expect(await tokens.calls == 0)
        for _ in 0..<2 { _ = try await model.generate(.init(messages: [.user("Hi")])) }
        #expect(await transport.requests().map { $0.headers["x-api-key"] } == ["key-1", "key-2"])
    }

    @Test func noneAndMinimalUseSharedNearestSupportedEffort() async throws {
        for reasoning in ["none", "minimal"] {
            let transport = RecordingTransport(response: jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
            let provider = try MiniMaxProvider(settings: .init(apiKey: "key", transport: transport))
            let result = try await provider.languageModel("minimax-m3.1").generate(.init(messages: [.user("Hi")], reasoning: reasoning))
            let request = try #require(await transport.requests().first)
            let body = try decodeJSONBody(try #require(request.body))
            #expect(body["output_config"]?["effort"] == "low")
            #expect(result.warnings.contains { $0.type == "compatibility" && $0.message == "reasoning \"\(reasoning)\" is not directly supported by this model. mapped to effort \"low\"." })
        }
    }
}
