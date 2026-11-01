import Foundation
import SwiftAIOpenAICompatible
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public func fireworksChatBody(from input: [String: JSONValue]) -> [String: JSONValue] {
    var warnings: [AIWarning] = []
    return fireworksChatBody(from: input, warnings: &warnings)
}

public func fireworksChatBody(from input: [String: JSONValue], warnings: inout [AIWarning]) -> [String: JSONValue] {
    var body = input

    if let value = body.removeValue(forKey: "reasoningEffort") {
        body["reasoning_effort"] = value
    }


    if let thinking = body.removeValue(forKey: "thinking")?.objectValue {
        var converted: [String: JSONValue] = [:]
        if let type = thinking["type"] { converted["type"] = type }
        if let budgetTokens = thinking["budgetTokens"] {
            converted["budget_tokens"] = budgetTokens
        } else if let budgetTokens = thinking["budget_tokens"] {
            converted["budget_tokens"] = budgetTokens
        }
        body["thinking"] = .object(converted)
    }

    if let reasoningHistory = body.removeValue(forKey: "reasoningHistory") {
        body["reasoning_history"] = reasoningHistory
    }

    return body
}

func fireworksPortableReasoning(_ reasoning: String, modelID: String, warnings: inout [AIWarning]) -> String? {
    let model = modelID.components(separatedBy: "/").last ?? ""
    var map = Dictionary(uniqueKeysWithValues: ["none", "minimal", "low", "medium", "high", "xhigh", "max"].map { ($0, $0) })
    if ["gpt-oss", "glm-5p3", "muse-spark"].contains(where: model.hasPrefix) { map.removeValue(forKey: "none") }
    if ["nemotron", "inkling"].contains(where: model.hasPrefix) { map.removeValue(forKey: "minimal") }
    return mapReasoningToProviderEffort(reasoning: reasoning, effortMap: map, warnings: &warnings)
}

/// Installs Fireworks request transformations and model-specific portable reasoning.
/// Explicit provider reasoning values bypass portable mapping.
public func configureFireworksChat(_ configuration: inout OpenAICompatibleModelConfiguration) {
    configuration.usesGenericOpenAICompatibleProviderOptions = true
    configuration.mapReasoning = { reasoning, modelID, warnings in
        fireworksPortableReasoning(reasoning, modelID: modelID, warnings: &warnings)
    }
    configuration.prepareBody = { body, _, _, warnings in fireworksChatBody(from: body, warnings: &warnings) }
}
