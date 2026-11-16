import Foundation
import Testing
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAITransport
@testable import SwiftAIZAI

// ZaiChatLanguageModel appends its warnings after the OpenAI-compatible base warnings,
// whose order is: provider-option deprecations, topK, responseFormat, tool warnings.
@Suite struct ZAIWarningOrderTests {
    @Test(arguments: [false, true])
    func warningsFollowUpstreamBaseThenZAIOrder(_ streaming: Bool) async throws {
        let raw = #"{"choices":[{"message":{"content":"answer"},"delta":{"content":"answer"},"finish_reason":"stop"}]}"#
        let transport = RecordingTransport(response: streaming ? sseResponse("data: " + raw) : jsonResponse(raw))
        let model = try createZai(configuration: .init(apiKey: "fixture", transport: transport)).languageModel("glm-5.3")
        let request = LanguageModelRequest(
            messages: [.user("hi")],
            topK: 5,
            seed: 1,
            responseFormat: .json(schema: ["type": "object"]),
            providerOptions: ["openai-compatible": ["user": "test-user-id"]]
        )
        var warnings: [AIWarning] = []
        if streaming {
            for try await part in model.stream(request) {
                if case let .streamStart(value) = part { warnings += value }
            }
        } else { warnings = try await model.generate(request).warnings }
        #expect(warnings == [
            AIWarning(type: "deprecated", setting: "providerOptions key 'openai-compatible'", message: "Use 'openaiCompatible' instead."),
            AIWarning(type: "unsupported", feature: "topK"),
            AIWarning(type: "unsupported", feature: "responseFormat", message: "JSON response format schema is only supported with structuredOutputs"),
            AIWarning(type: "unsupported", feature: "seed")
        ])
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["user"] == nil)
        #expect(body["response_format"] == ["type": "json_object"])
    }
}
