import Foundation
import Testing
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAITransport
@testable import SwiftAIGoogleVertex

@Suite struct Weekly20261108VertexOutputPolicyTests {
    @Test func sharedAnthropicOverridesRemainDistinctFromAutomaticHostOptIn() async throws {
        let schema: JSONValue = ["type": "object", "properties": ["value": ["type": "string"]],
                                 "required": ["value"], "additionalProperties": false]
        let cases: [(String, String?, Bool)] = [
            ("claude-sonnet-4-5", nil, false),
            ("claude-sonnet-5-5", nil, true),
            ("claude-sonnet-4-5", "outputFormat", true)
        ]
        for (modelID, mode, native) in cases {
            let transport = RecordingTransport(response: jsonResponse(#"{"id":"m","type":"message","role":"assistant","content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}"#))
            let provider = try GoogleVertexHostedProvider(endpoint: .anthropic,
                configuration: .init(apiKey: "token", baseURL: "https://example.com", transport: transport))
            let options: [String: JSONValue] = mode.map { ["googleVertex": ["structuredOutputMode": .string($0)]] } ?? [:]
            _ = try await provider.languageModel(modelID).generate(.init(messages: [.user("json")],
                responseFormat: .json(schema: schema), providerOptions: options))
            let body = try decodeJSONBody(#require(await transport.requests().first?.body))
            #expect((body["output_config"]?["format"] != nil) == native)
        }
    }
}
