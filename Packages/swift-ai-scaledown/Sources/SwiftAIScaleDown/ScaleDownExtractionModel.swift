import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public struct ScaleDownExtractionModelOptions: Equatable, Sendable {
    public var threshold: Double?
    public init(threshold: Double? = nil) { self.threshold = threshold }
    public var providerOptions: [String: JSONValue] {
        ["scaledown": .object(["threshold": threshold.map(JSONValue.number)])]
    }
}

public final class ScaleDownExtractionModel: AIExtractionModelV4, Sendable {
    public let providerID = "scaledown.extraction"
    public let supportedFieldTypes: [AIExtractionFieldType] = [.text, .list]
    public let modelID: String
    private let configuration: ScaleDownConfiguration

    init(modelID: String, configuration: ScaleDownConfiguration) {
        self.modelID = modelID; self.configuration = configuration
    }

    public func doExtract(_ options: AIExtractionModelV4CallOptions) async throws -> AIExtractionModelV4Result {
        try options.abortSignal?.throwIfAborted()
        var properties: [String: JSONValue] = [:]
        for (id, field) in options.fields {
            guard field.type == .text || (field.type == .list && field.items == .text) else {
                throw AIExtractionUnsupportedFieldTypeError(fieldID: id, fieldType: field.type, providerID: providerID, modelID: modelID,
                    message: "Field \"\(id)\" has type \"\(field.type == .list ? "list<\(field.items?.rawValue ?? "unknown")>" : field.type.rawValue)\", which is not supported by provider \"\(providerID)\" and model \"\(modelID)\".")
            }
            properties[id] = .object(["type": "string", "description": try field.instructions.flatMap { value in
                value == .null ? nil : .string(try scaleDownText(value))
            }, "top_n": field.type == .text ? 1 : 0])
        }
        let threshold = try extractionThreshold(options.providerOptions)
        var state = try scaleDownState(options.state)
        var input = state.removeValue(forKey: "text")?.stringValue ?? ""
        if state["document"] != nil && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input = "Extract the requested fields from the document."
        }
        var fields: [String: JSONValue?] = [
            "model": .string(modelID), "messages": [["role": "user", "content": .string(input)]],
            "response_format": ["type": "json_schema", "json_schema": ["name": "extraction", "schema": ["type": "object", "properties": .object(properties)]]],
            "threshold": threshold.map(JSONValue.number), "context_chars": 0
        ]
        for (key, value) in state { fields[key] = value }
        let body = JSONValue.object(fields)
        let (request, response, raw) = try await configuration.send(path: "/v1/chat/completions", providerID: providerID,
                                                                  body: body, headers: options.headers, signal: options.abortSignal)
        let envelope: ScaleDownExtractionEnvelope
        do { envelope = try parseExtractionEnvelope(raw) }
        catch { throw AIError.apiCall(responseError(request, response, body, providerID, message: "ScaleDown returned an invalid extraction response.")) }
        let content: ScaleDownExtractionContent
        do { content = try parseExtractionContent(envelope.content) }
        catch { throw ScaleDownInvalidExtractionContentError(data: envelope.content) }
        var answers: [String: AIExtractionAnswer] = [:]
        for (id, field) in options.fields {
            let matches = content.entities.filter { $0.type == id && !$0.text.isEmpty }
            if field.type == .list {
                let items = try matches.map { entity in
                    AIExtractionItem(confidence: entity.confidence,
                        source: try scaleDownExtractionSource(text: entity.text, start: entity.start, end: entity.end,
                                                             state: options.state, ocrText: content.ocrText))
                }
                answers[id] = .init(type: .list, value: .array(matches.map { .string($0.text) }), items: items)
            } else {
                // Equal confidence retains the first entity, just like upstream reduce().
                let match = matches.reduce(nil as ScaleDownEntity?) { best, entity in
                    best == nil || entity.confidence > best!.confidence ? entity : best
                }
                answers[id] = .init(type: .text, value: match.map { .string($0.text) }, confidence: match?.confidence,
                    source: try match.flatMap { try scaleDownExtractionSource(text: $0.text, start: $0.start, end: $0.end,
                                                                           state: options.state, ocrText: content.ocrText) })
            }
        }
        var warnings: [AIWarning] = []
        if options.referenceDate != nil { warnings.append(.init(type: "unsupported", feature: "referenceDate")) }
        if options.maxOutputTokens != nil { warnings.append(.init(type: "unsupported", feature: "maxOutputTokens")) }
        if options.reasoning != nil { warnings.append(.init(type: "unsupported", feature: "reasoning")) }
        return .init(answers: answers, usage: .init(inputTokens: envelope.inputTokens ?? content.inputTokens, outputTokens: envelope.outputTokens),
                     warnings: warnings, providerMetadata: content.ocrText.map { ["scaledown": ["ocrText": .string($0)]] } ?? [:],
                     response: .init(id: envelope.id, timestamp: envelope.created.map(Date.init(timeIntervalSince1970:)),
                                     modelID: envelope.modelID ?? modelID, headers: response.headers, body: raw))
    }
}

private func extractionThreshold(_ providerOptions: [String: JSONValue]) throws -> Double? {
    guard let value = providerOptions["scaledown"], value != .null else { return nil }
    guard let object = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.scaledown", message: "Expected an object.")
    }
    guard let threshold = object["threshold"] else { return nil }
    guard let number = threshold.doubleValue, number.isFinite, (0...1).contains(number) else {
        throw AIError.invalidArgument(argument: "providerOptions.scaledown.threshold", message: "Expected a number from 0 to 1.")
    }
    return number
}

private struct ScaleDownExtractionEnvelope {
    var content: String
    var id: String?
    var created: Double?
    var modelID: String?
    var inputTokens: Int?
    var outputTokens: Int?
}
private struct ScaleDownEntity {
    var text: String
    var type: String
    var confidence: Double
    var start: Int?
    var end: Int?
}
private struct ScaleDownExtractionContent {
    var entities: [ScaleDownEntity]
    var inputTokens: Int?
    var ocrText: String?
}

private func parseExtractionEnvelope(_ raw: JSONValue) throws -> ScaleDownExtractionEnvelope {
    guard raw.objectValue != nil, let choices = raw["choices"]?.arrayValue, !choices.isEmpty else { throw ScaleDownSchemaError() }
    // Every choice is schema-validated even though only the first content is consumed.
    guard choices.allSatisfy({ $0["message"]?["content"]?.stringValue != nil }),
          let content = choices.first?["message"]?["content"]?.stringValue else { throw ScaleDownSchemaError() }
    let usage = try scaleDownOptionalObject(raw["usage"])
    return ScaleDownExtractionEnvelope(content: content, id: try scaleDownOptionalString(raw["id"]),
                                       created: try scaleDownOptionalNumber(raw["created"]), modelID: try scaleDownOptionalString(raw["model"]),
                                       inputTokens: try scaleDownTokenCount(usage?["prompt_tokens"]), outputTokens: try scaleDownTokenCount(usage?["completion_tokens"]))
}
private func parseExtractionContent(_ text: String) throws -> ScaleDownExtractionContent {
    let raw = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    guard let entities = raw["entities"]?.arrayValue else { throw ScaleDownSchemaError() }
    return ScaleDownExtractionContent(entities: try entities.map { entity in
        guard let text = entity["text"]?.stringValue, let type = entity["type"]?.stringValue,
              let confidence = try scaleDownOptionalNumber(entity["confidence"]) else { throw ScaleDownSchemaError() }
        func offset(_ value: JSONValue?) throws -> Int? {
            guard let number = try scaleDownOptionalNumber(value) else { return nil }
            guard number >= 0, let integer = Int(exactly: number) else { throw ScaleDownSchemaError() }; return integer
        }
        return ScaleDownEntity(text: text, type: type, confidence: confidence, start: try offset(entity["start"]), end: try offset(entity["end"]))
    }, inputTokens: try scaleDownTokenCount(raw["input_tokens"]), ocrText: try scaleDownOptionalString(raw["ocr_text"]))
}
