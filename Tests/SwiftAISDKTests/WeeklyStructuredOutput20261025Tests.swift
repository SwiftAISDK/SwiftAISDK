import Foundation
import Testing
@testable import SwiftAISDK

@Suite("WeeklyStructuredOutput20261025")
struct WeeklyStructuredOutput20261025Tests {
    private func message(_ phase: String?, _ texts: [String], id: String) -> JSONValue {
        var value: [String: JSONValue] = ["type": "message", "id": .string(id), "role": "assistant", "status": "completed", "content": .array(texts.map { ["type": "output_text", "text": .string($0), "annotations": .array([JSONValue]())] })]
        value["phase"] = phase.map(JSONValue.string)
        return .object(value)
    }

    @Test(arguments: ["json", "text"], ["split", "empty", "missing", "no-final", "incomplete"])
    func responsesSelectLastFinalAnswerWithoutRemovingAnyContent(_ format: String, _ ending: String) async throws {
        let finalTexts = ending == "empty" ? [""] : ending == "missing" ? [] : ending == "split" ? ["{\"items\":", "[\"result\"]}"] : ["{\"items\":"]
        let outputs: [JSONValue] = [
            message("commentary", ["Draft answer"], id: "draft"),
            message("final_answer", ["{\"items\":[]}"], id: "first"),
            message(ending == "no-final" ? "commentary" : "final_answer", finalTexts, id: "last")
        ]
        let raw: JSONValue = ["id": "resp1", "status": "completed", "output": .array(outputs), "usage": ["input_tokens": 2, "output_tokens": 3]]
        let transport = RecordingTransport(response: jsonResponse(String(decoding: try encodeJSONBody(raw), as: UTF8.self)))
        let model = try AIProviders.openAI(settings: .init(apiKey: "offline-key", transport: transport)).responses("gpt-5.3-codex")
        let result = try await model.generate(.init(messages: [.user("JSON please")], responseFormat: format == "json" ? .json() : .text))
        let selected = ending == "no-final" ? "{\"items\":[]}" : finalTexts.joined()
        #expect(result.structuredOutputText == (format == "json" ? selected : nil))
        #expect(result.text == "Draft answer{\"items\":[]}" + finalTexts.joined())
        #expect(result.rawValue == raw)
        let phases = result.content.compactMap { part -> String? in
            if case let .text(_, metadata) = part { metadata["openai"]?["phase"]?.stringValue } else { nil }
        }
        #expect(phases.first == "commentary")
        #expect(phases.contains("final_answer"))
    }

    @Test func jsonWithoutFinalPhaseDoesNotSetSelection() async throws {
        let raw: JSONValue = ["id": "resp1", "status": "completed", "output": [message(nil, ["{}"], id: "m")]]
        let transport = RecordingTransport(response: jsonResponse(String(decoding: try encodeJSONBody(raw), as: UTF8.self)))
        let model = try AIProviders.openAI(settings: .init(apiKey: "key", transport: transport)).responses("gpt-4o")
        let result = try await model.generate(.init(messages: [.user("Hello")], responseFormat: .json()))
        #expect(result.structuredOutputText == nil)
        #expect(result.text == "{}")
    }

    @Test func huggingFaceToolChoiceNoneKeepsToolDefinitions() async throws {
        let transport = RecordingTransport(response: sseResponse(#"data: {"type":"response.completed","response":{"id":"r1","status":"completed","output":[],"usage":null}}"#))
        let model = try AIProviders.huggingFace(settings: .init(apiKey: "key", transport: transport)).languageModel("test-model")
        let request = LanguageModelRequest(messages: [.user("Hello")], tools: ["test": ["type": "object"]], toolChoice: ["type": "none"])
        for try await _ in model.stream(request) {}
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["tool_choice"] == "none")
        #expect(body["tools"]?[0]?["name"] == "test")
        #expect(body["tools"]?[0]?["parameters"] == ["type": "object"])
    }
}
