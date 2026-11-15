import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

public final class ScaleDownDecisionModel: AIDecisionModelV4, Sendable {
    public let providerID = "scaledown.decision"
    public let supportedQuestionTypes: [AIDecisionQuestionType] = [.choice, .boolean, .score]
    public let modelID: String
    private let configuration: ScaleDownConfiguration

    init(modelID: String, configuration: ScaleDownConfiguration) {
        self.modelID = modelID; self.configuration = configuration
    }

    public func doDecide(_ options: AIDecisionModelV4CallOptions) async throws -> AIDecisionModelV4Result {
        try options.abortSignal?.throwIfAborted()
        var nativeQuestions: [String: JSONValue] = [:]
        for (id, question) in options.questions {
            let instructions: String? = question.instructions == .null ? nil : try scaleDownText(question.instructions)
            switch question {
            case let .choice(_, criteria):
                let nativeCriteria = try Dictionary(uniqueKeysWithValues: criteria.map { key, value in
                    (key, JSONValue.string(value == .null ? key : try scaleDownText(value)))
                })
                nativeQuestions[id] = .object(["type": "choice", "instructions": instructions.map(JSONValue.string),
                                               "criteria": .object(nativeCriteria)])
            case let .boolean(_, criteria):
                var lines = instructions.map { [$0] } ?? []
                // Swift dictionaries have no insertion order; boolean rubrics use their semantic yes/no order.
                for key in (criteria ?? [:]).keys.sorted(by: { lhs, rhs in
                    if lhs == "true" { return rhs != "true" }
                    if rhs == "true" { return false }
                    return lhs < rhs
                }) {
                    if let value = criteria?[key], value != .null {
                        lines.append("Answer \(key == "true" ? "yes" : "no") when: \(try scaleDownText(value))")
                    }
                }
                nativeQuestions[id] = ["type": "noul", "instructions": .string(lines.joined(separator: "\n"))]
            case let .score(_, criteria):
                guard (2...10).contains(criteria.count), !criteria.contains(.null) else {
                    throw AIError.invalidArgument(argument: "questions.\(id).criteria", message: "ScaleDown Score questions require 2 to 10 non-null levels.")
                }
                nativeQuestions[id] = .object(["type": "score", "instructions": instructions.map(JSONValue.string),
                                               "criteria": .array(try criteria.map { .string(try scaleDownText($0)) })])
            case .box:
                throw AIDecisionUnsupportedQuestionTypeError(questionID: id, questionType: .box, providerID: providerID, modelID: modelID)
            }
        }
        let body: JSONValue = ["model": .string(modelID), "state": .object(try scaleDownState(options.state)), "questions": .object(nativeQuestions)]
        let (request, response, raw) = try await configuration.send(path: "/v1/scaledown", providerID: providerID,
                                                                  body: body, headers: options.headers, signal: options.abortSignal)
        let parsed: ParsedDecision
        do { parsed = try parseScaleDownDecision(raw) }
        catch { throw AIError.apiCall(responseError(request, response, body, providerID, message: "ScaleDown returned an invalid decision response.")) }
        var warnings: [AIWarning] = []
        if options.maxOutputTokens != nil { warnings.append(.init(type: "unsupported", feature: "maxOutputTokens")) }
        if options.reasoning != nil { warnings.append(.init(type: "unsupported", feature: "reasoning")) }
        for key in options.providerOptions["scaledown"]?.objectValue?.keys.sorted() ?? [] {
            warnings.append(.init(type: "unsupported", feature: "providerOptions.scaledown.\(key)"))
        }
        var metadata: [String: JSONValue] = ["confidence": .object(parsed.confidence), "legend": .object(parsed.legend)]
        if let cost = parsed.cost { metadata["cost"] = .number(cost) }
        return .init(answers: parsed.answers, usage: parsed.usage, warnings: warnings,
                     providerMetadata: ["scaledown": .object(metadata)],
                     response: AIResponseMetadata(modelID: parsed.modelID ?? modelID, headers: response.headers, body: raw))
    }
}

/// Upstream class-name alias; both names refer to the same native implementation.
public typealias DecisionScaleDownModel = ScaleDownDecisionModel

private struct ParsedDecision {
    var modelID: String?
    var answers: [String: AIDecisionAnswer] = [:]
    var confidence: [String: JSONValue] = [:]
    var legend: [String: JSONValue] = [:]
    var usage: AIDecisionModelUsage
    var cost: Double?
}

private func parseScaleDownDecision(_ raw: JSONValue) throws -> ParsedDecision {
    guard raw.objectValue != nil, let answers = raw["answers"]?.objectValue else { throw ScaleDownSchemaError() }
    let usage = try scaleDownOptionalObject(raw["usage"])
    var parsed = ParsedDecision(modelID: try scaleDownOptionalString(raw["model"]),
                                usage: .init(inputTokens: try scaleDownTokenCount(usage?["input_tokens"]),
                                             outputTokens: try scaleDownTokenCount(usage?["output_tokens"])),
                                cost: try scaleDownOptionalNumber(usage?["cost"]))
    for (id, answer) in answers {
        guard let type = answer["type"]?.stringValue else { throw ScaleDownSchemaError() }
        switch type {
        case "noul":
            guard let number = try scaleDownOptionalNumber(answer["noul"]) else { throw ScaleDownSchemaError() }
            parsed.answers[id] = .boolean(probability: number)
        case "choice", "score":
            guard let probabilities = answer["probabilities"]?.objectValue else { throw ScaleDownSchemaError() }
            let numbers = try probabilities.mapValues { value -> Double in
                guard let number = try scaleDownOptionalNumber(value) else { throw ScaleDownSchemaError() }; return number
            }
            if type == "choice" {
                guard let choice = answer["choice"]?.stringValue else { throw ScaleDownSchemaError() }
                parsed.answers[id] = .choice(choice: choice, probabilities: numbers)
            } else {
                guard let score = try scaleDownOptionalNumber(answer["score"]) else { throw ScaleDownSchemaError() }
                parsed.answers[id] = .score(score: score, probabilities: numbers)
                if let legend = try scaleDownOptionalObject(answer["legend"]) {
                    guard legend.values.allSatisfy({ $0.stringValue != nil }) else { throw ScaleDownSchemaError() }
                    parsed.legend[id] = .object(legend)
                }
            }
            if let confidence = try scaleDownOptionalNumber(answer["confidence"]) { parsed.confidence[id] = .number(confidence) }
        default: throw ScaleDownSchemaError()
        }
    }
    return parsed
}
