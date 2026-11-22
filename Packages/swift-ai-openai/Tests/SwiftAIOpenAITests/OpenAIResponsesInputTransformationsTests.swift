import Foundation
import Testing
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAITransport
@testable import SwiftAIOpenAI

@Suite struct OpenAIResponsesInputTransformationsTests {
    private static let removedReasoning: JSONValue = [
        "id": "rs_1", "type": "reasoning", "action": "removed", "reason": "prefix_mismatch"
    ]

    // openai-responses-input-transformations.test.ts, @ai-sdk/openai@4.0.122.
    @Test(arguments: [false, true], [
        .array([removedReasoning]),
        [
            ["id": "rs_1", "type": "reasoning", "action": "removed", "reason": "end_user_mismatch"],
            ["id": "rs_2", "type": "reasoning", "action": "removed", "reason": "model_mismatch"]
        ],
        [],
        [["type": "reasoning", "action": "future_action", "reason": "future_reason"]],
        .null,
        nil
    ] as [JSONValue?])
    func preservesInputTransformations(stream: Bool, transformations: JSONValue?) async throws {
        var response: [String: JSONValue] = [
            "id": "resp_test", "created_at": 0, "model": "gpt-6.2-astra", "output": []
        ]
        response["input_transformations"] = transformations
        let request = LanguageModelRequest(messages: [.user("Hello")])
        let metadata: [String: JSONValue]
        if stream {
            let parts = try await streamParts([["type": "response.completed", "response": .object(response)]])
            let finished = try #require(parts.compactMap(finish).first)
            metadata = finished.providerMetadata
        } else {
            let transport = RecordingTransport(response: .init(statusCode: 200, body: try encodeJSONBody(.object(response))))
            metadata = try await model(transport).generate(request).providerMetadata
        }
        #expect(metadata["openai"]?["inputTransformations"] == (transformations == .null ? nil : transformations))
    }

    @Test func preservesTransformationsWhenStreamFailsAfterOutputStarts() async throws {
        let transformations: JSONValue = [Self.removedReasoning]
        let parts = try await streamParts([
            ["type": "response.created", "response": ["id": "resp_test", "created_at": 0, "model": "gpt-6.2-astra"]],
            ["type": "response.output_item.added", "output_index": 0, "item": ["id": "msg_1", "type": "message"]],
            ["type": "response.failed", "sequence_number": 2, "response": [
                "error": ["code": "server_error", "message": "failed"],
                "input_transformations": transformations
            ]]
        ])
        let finished = try #require(parts.compactMap(finish).first)
        #expect(finished.providerMetadata["openai"]?["inputTransformations"] == transformations)
        #expect(finished.reason == "error")
        #expect(parts.compactMap(\.streamProviderError).first?.message == "failed")
        #expect(parts.compactMap(\.streamProviderError).first?.code == "server_error")
    }

    @Test func incompleteStreamUsesOnlyTerminalTransformationsAndNormalizesFields() async throws {
        let item: JSONValue = ["id": .null, "type": "future_type", "action": "future_action", "reason": "future_reason"]
        var wireItem = try #require(item.objectValue)
        wireItem["future_field"] = "value"
        let parts = try await streamParts([
            ["type": "response.created", "response": [
                "id": "resp_test", "input_transformations": [Self.removedReasoning]
            ]],
            ["type": "response.incomplete", "response": [
                "incomplete_details": ["reason": "max_output_tokens"], "input_transformations": [.object(wireItem)]
            ]]
        ])
        let finished = try #require(parts.compactMap(finish).first)
        #expect(finished.providerMetadata["openai"]?["inputTransformations"] == [item])
        #expect(finished.reason == "length")
    }

    @Test(arguments: [
        .object(["type": "reasoning", "action": "removed", "reason": "prefix_mismatch"]),
        [["type": "reasoning", "action": "removed"]],
        [["id": 1, "type": "reasoning", "action": "removed", "reason": "prefix_mismatch"]]
    ] as [JSONValue])
    func rejectsMalformedTerminalTransformations(value: JSONValue) async throws {
        let response: JSONValue = [
            "id": "resp_test", "model": "gpt-6.2-astra", "output": [],
            "input_transformations": value
        ]
        let transport = RecordingTransport(response: .init(statusCode: 200, body: try encodeJSONBody(response)))
        await #expect(throws: AIError.self) {
            _ = try await model(transport).generate(.init(messages: [.user("Hello")]))
        }
        let event: JSONValue = ["type": "response.completed", "response": response]
        let parts = try await streamParts([event])
        #expect(parts.contains { part in
            if case let .error(_, rawValue) = part { return rawValue == event }
            return false
        })
        let finished = try #require(parts.compactMap(finish).first)
        #expect(finished.reason == "error")
        #expect(finished.providerMetadata["openai"]?["inputTransformations"] == nil)
    }

    private func model(_ transport: RecordingTransport) throws -> any BatchLanguageModel {
        try OpenAIProvider(configuration: .init(apiKey: "test-key", transport: transport)).responses("gpt-6.2-astra")
    }

    private func streamParts(_ events: [JSONValue]) async throws -> [LanguageStreamPart] {
        let body = try events.map { "data: " + String(decoding: try encodeJSONBody($0), as: UTF8.self) }
            .joined(separator: "\n\n")
        let transport = RecordingTransport(response: sseResponse(body))
        var parts: [LanguageStreamPart] = []
        for try await part in try model(transport).stream(.init(messages: [.user("Hello")])) {
            parts.append(part)
        }
        return parts
    }

    private func finish(_ part: LanguageStreamPart) -> (reason: String?, providerMetadata: [String: JSONValue])? {
        guard case let .finishMetadata(reason, _, providerMetadata) = part else { return nil }
        return (reason, providerMetadata)
    }
}
