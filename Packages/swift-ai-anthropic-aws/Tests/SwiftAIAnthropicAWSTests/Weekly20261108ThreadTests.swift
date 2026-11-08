import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAnthropicAWS

@Suite struct Weekly20261108AnthropicAWSThreads {
    @Test func awsPlatformOptsIntoThreadsWithCanonicalAnthropicOptions() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
        let provider = try AnthropicAWSProvider(settings: .init(region: "us-east-1", workspaceID: "workspace", apiKey: "key", transport: transport))
        _ = try await provider.languageModel("claude-sonnet-4-6").generate(.init(messages: [.user("Hi")], providerOptions: ["anthropic": ["thread": ["type": "create"]]]))
        let request = try #require(await transport.requests().first)
        let body = try decodeJSONBody(try #require(request.body))
        #expect(body["thread"] == ["type": "create"])
        #expect(request.headers["anthropic-beta"]?.contains("message-threads-2026-08-12") == true)
        #expect(request.headers["anthropic-workspace-id"] == "workspace")
    }
}
