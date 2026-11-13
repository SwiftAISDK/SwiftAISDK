import Foundation
import Testing
import SwiftAIProvider
import SwiftAIProviderUtilities
@testable import SwiftAITransport
@testable import SwiftAITogetherAI

@Suite struct Weekly20261114StructuredOutputTests {
    @Test(arguments: [
        ("deepseek-ai/DeepSeek-V4-Flash-0731", true),
        ("deepseek-ai/DeepSeek-V4.1-Flash", true),
        ("deepseek-ai/DeepSeek-V4.1-Flash-1017", true),
        ("openai/gpt-oss-120b", true),
        ("zai-org/GLM-5.2", true),
        ("zai-org/GLM-5.3-Flash", true),
        ("moonshotai/Kimi-K3", true),
        ("MiniMaxAI/MiniMax-M3.1-Flash", true),
        ("zai-org/GLM-5.3", false),
        ("custom-model-id", false)
    ], [false, true])
    func exactCatalogIDsControlSchemaForwarding(_ fixture: (String, Bool), _ streaming: Bool) async throws {
        let raw = #"{"choices":[{"message":{"content":"{}"},"delta":{"content":"{}"},"finish_reason":"stop"}]}"#
        let transport = RecordingTransport(response: streaming ? sseResponse("data: " + raw) : jsonResponse(raw))
        let provider = try TogetherAIProvider(configuration: .init(apiKey: "test-key", transport: transport))
        let request = LanguageModelRequest(messages: [.user("Return JSON")], extraBody: [
            "responseFormat": [
                "type": "json", "name": "answer",
                "schema": ["type": "object", "properties": ["value": ["type": "string", "enum": ["schema-only-value"]]]]
            ]
        ])
        let model = try provider.chatModel(fixture.0)
        if streaming { for try await _ in model.stream(request) {} }
        else { _ = try await model.generate(request) }
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["response_format"]?["type"] == .string(fixture.1 ? "json_schema" : "json_object"))
        #expect((body["response_format"]?["json_schema"] != nil) == fixture.1)
    }
}
