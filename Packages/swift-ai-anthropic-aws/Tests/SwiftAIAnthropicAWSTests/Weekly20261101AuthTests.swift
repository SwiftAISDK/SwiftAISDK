import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAnthropicAWS

private actor WeeklyAWSTokens {
    var calls = 0
    func next() -> String { calls += 1; return " key-\(calls) " }
}

@Suite struct Weekly20261101AnthropicAWS {
    @Test func callbackAuthRotatesWithoutSigV4AndPreservesNonblankWhitespace() async throws {
        let tokens = WeeklyAWSTokens()
        let transport = RecordingTransport(response: jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
        let provider = try AnthropicAWSProvider(settings: .init(region: "us-east-1", workspaceID: "workspace", transport: transport, apiKeyProvider: { await tokens.next() }))
        let model = try provider.languageModel("claude-sonnet-4-6")
        #expect(await tokens.calls == 0)
        for _ in 0..<2 { _ = try await model.generate(.init(messages: [.user("Hi")])) }
        let requests = await transport.requests()
        #expect(requests.map { $0.headers["x-api-key"] } == [" key-1 ", " key-2 "])
        #expect(requests.allSatisfy { $0.headers["authorization"] == nil && $0.headers["anthropic-workspace-id"] == "workspace" })
    }

    @Test func blankCallbackFailsBeforeNetwork() async throws {
        let transport = RecordingTransport(response: jsonResponse("{}"))
        let provider = try AnthropicAWSProvider(settings: .init(region: "us-east-1", workspaceID: "workspace", transport: transport, apiKeyProvider: { " \n" }))
        await #expect(throws: (any Error).self) { _ = try await provider.languageModel("claude-sonnet-4-6").generate(.init(messages: [.user("Hi")])) }
        #expect(await transport.requests().isEmpty)
    }
}
