import Foundation
import Testing
@testable import SwiftAIXAI
import SwiftAIProvider
import SwiftAITransport

@Suite struct Weekly20261101XAITests {
    @Test func reasoningMatchesExactCatalogBoundaries() {
        for modelID in ["grok-4.3", "grok-latest", "grok-4-fast", "grok-4.20-multi-agent", "grok-4.20-multi-agent-0309", "grok-3-mini", "grok-4.50", "grok-100-latest"] {
            var warnings: [AIWarning] = []
            let value = xaiReasoningEffort("none", modelID: modelID, warnings: &warnings)
            #expect(value == (modelID == "grok-100-latest" ? "low" : "none"))
        }
        for modelID in ["grok-4.5", "grok-4.6", "grok-4.7", "grok-4.7-fast", "grok-5", "grok-5.1", "grok-4.5preview"] {
            var warnings: [AIWarning] = []
            #expect(xaiReasoningEffort("none", modelID: modelID, warnings: &warnings) == "low")
            #expect(warnings.contains { $0.type == "compatibility" && $0.feature == "reasoning" })
        }
        for (model, expected) in [("grok-4.6", "xhigh"), ("grok-4.7", "high"), ("grok-4.6-2026", "high")] {
            var warnings: [AIWarning] = []
            #expect(xaiReasoningEffort("xhigh", modelID: model, warnings: &warnings) == expected)
        }
    }

    @Test func streamedCitationIsNotRepeatedByDoneItemAndDoneOnlyCitationSurvives() async throws {
        for mode in ["streamed", "done-only", "added-without-delta"] {
            let annotation: JSONValue = ["type": "url_citation", "url": "https://example.com", "title": "example"]
            var events: [JSONValue] = [["type": "response.created", "response": ["id": "resp", "model": "grok-4.7", "status": "in_progress", "output": []]]]
            if mode == "added-without-delta" {
                events.append(["type": "response.output_item.added", "output_index": 0, "item": ["type": "message", "id": "msg", "role": "assistant", "content": []]])
            }
            if mode == "streamed" {
                events += [["type": "response.output_text.delta", "item_id": "msg", "output_index": 0, "content_index": 0, "delta": "Hello"],
                           ["type": "response.output_text.annotation.added", "item_id": "msg", "output_index": 0, "content_index": 0, "annotation_index": 0, "annotation": annotation]]
            }
            events += [["type": "response.output_item.done", "output_index": 0, "item": ["type": "message", "id": "msg", "status": "completed", "role": "assistant", "content": [["type": "output_text", "text": "Hello", "annotations": [annotation]]]]],
                       ["type": "response.done", "response": ["id": "resp", "status": "completed", "output": [], "usage": ["input_tokens": 1, "output_tokens": 1]]]]
            let body = try events.map { "data: " + String(decoding: try encodeJSONBody($0), as: UTF8.self) }.joined(separator: "\n\n") + "\n\n"
            let transport = RecordingTransport(response: sseResponse(body))
            let model = try XAIProvider(configuration: .init(apiKey: "token", transport: transport)).responses("grok-4.7")
            var urls: [String] = []
            var text = ""
            for try await part in model.stream(.init(messages: [.user("Hello")])) {
                if case let .source(source) = part { if let url = source.url { urls.append(url) } }
                if case let .textDeltaPart(_, delta, _) = part { text += delta }
            }
            #expect(urls == ["https://example.com"])
            #expect(text == "Hello")
        }
    }
}
