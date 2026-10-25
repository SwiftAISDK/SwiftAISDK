import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
func xaiResponsesOptions(from extraBody: [String: JSONValue]) -> [String: JSONValue] {
    var output = extraBody
    if let topLogprobs = output.removeValue(forKey: "topLogprobs") {
        output["top_logprobs"] = topLogprobs
        output["logprobs"] = output["logprobs"] ?? .bool(true)
    }
    if output["store"]?.boolValue == true {
        output.removeValue(forKey: "store")
    } else if output["store"]?.boolValue == false {
        var include = output["include"]?.arrayValue ?? []
        if !include.contains(.string("reasoning.encrypted_content")) {
            include.append(.string("reasoning.encrypted_content"))
        }
        output["include"] = .array(include)
    } else if output["include"] == .null {
        output.removeValue(forKey: "include")
    }
    return output
}
func xaiResponsesProviderOptions(providerOptions: [String: JSONValue], extraBody: [String: JSONValue], providerID: String) throws -> [String: JSONValue] {
    var output = openAICompatibleProviderOptions(from: extraBody, providerID: providerID, includeCompatibilityNamespace: false)
    if let value = providerOptions["xai"] {
        guard value != .null else { return output }
        guard let nested = value.objectValue else {
            throw AIError.invalidArgument(argument: "providerOptions.xai", message: "xAI responses provider options must be an object.")
        }
        output.merge(try xaiValidateResponsesProviderOptions(nested)) { _, nested in nested }
    }
    return output
}
func xaiValidateResponsesProviderOptions(_ options: [String: JSONValue]) throws -> [String: JSONValue] {
    let allowedKeys: Set<String> = [
        "reasoningEffort",
        "reasoningSummary",
        "logprobs",
        "topLogprobs",
        "store",
        "previousResponseId",
        "include"
    ]
    var output: [String: JSONValue] = [:]
    for (key, value) in options where allowedKeys.contains(key) {
        switch key {
        case "reasoningEffort":
            guard let effort = value.stringValue, ["none", "low", "medium", "high"].contains(effort) else {
                throw AIError.invalidArgument(argument: "providerOptions.xai.reasoningEffort", message: "xAI reasoningEffort must be none, low, medium, or high.")
            }
        case "reasoningSummary":
            guard let summary = value.stringValue, ["auto", "concise", "detailed"].contains(summary) else {
                throw AIError.invalidArgument(argument: "providerOptions.xai.reasoningSummary", message: "xAI reasoningSummary must be auto, concise, or detailed.")
            }
        case "logprobs", "store":
            guard value.boolValue != nil else {
                throw AIError.invalidArgument(argument: "providerOptions.xai.\(key)", message: "xAI \(key) must be a boolean.")
            }
        case "topLogprobs":
            guard let topLogprobs = value.intValue,
                  value.doubleValue == Double(topLogprobs),
                  (0...8).contains(topLogprobs) else {
                throw AIError.invalidArgument(argument: "providerOptions.xai.topLogprobs", message: "xAI topLogprobs must be an integer from 0 to 8.")
            }
        case "previousResponseId":
            guard value.stringValue != nil else {
                throw AIError.invalidArgument(argument: "providerOptions.xai.previousResponseId", message: "xAI previousResponseId must be a string.")
            }
        case "include":
            if value == .null {
                break
            }
            guard let values = value.arrayValue,
                  values.allSatisfy({ $0.stringValue == "file_search_call.results" }) else {
                throw AIError.invalidArgument(argument: "providerOptions.xai.include", message: "xAI include must contain only file_search_call.results or be null.")
            }
        default:
            break
        }
        output[key] = value
    }
    return output
}
