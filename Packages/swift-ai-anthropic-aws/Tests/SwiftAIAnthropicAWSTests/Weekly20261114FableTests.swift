import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAnthropicAWS

@Suite struct Weekly20261114FableTests {
    @Test func fableFiveTwoUsesTheSharedAnthropicForcedToolFallback() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
        let provider = try AnthropicAWSProvider(settings: .init(region: "us-east-1", workspaceID: "workspace", apiKey: "key", transport: transport))
        _ = try await provider.languageModel("claude-fable-5-2").generate(.init(messages: [.user("Lookup")], tools: ["lookup": ["type": "object", "properties": [:]]], toolChoice: ["type": "required"]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["tool_choice"] == ["type": "auto"])
        #expect(body["max_tokens"] == 128000)
    }
}
