import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
public func openAICompatibleResponseMetadata(from raw: JSONValue? = nil, response: AIHTTPResponse, modelID: String? = nil, suppressZeroCreatedTimestamp: Bool = false) -> AIResponseMetadata {
    let created = raw?["created"]?.doubleValue
    return AIResponseMetadata(
        id: raw?["id"]?.stringValue,
        timestamp: suppressZeroCreatedTimestamp && created == 0
            ? nil
            : created.map { Date(timeIntervalSince1970: $0) },
        modelID: raw?["model"]?.stringValue ?? modelID,
        headers: response.headers,
        body: raw
    )
}
func openAICompatibleChatResponseHasMetadata(_ raw: JSONValue, suppressZeroCreatedTimestamp: Bool) -> Bool {
    if suppressZeroCreatedTimestamp,
       raw["created"]?.doubleValue == 0,
       raw["id"]?.stringValue?.isEmpty != false,
       raw["model"]?.stringValue?.isEmpty != false {
        return false
    }
    return true
}
public func openAICompatibleProviderMetadataNamespace(_ providerID: String, providerOptions: [String: JSONValue]? = nil) -> String {
    if let providerOptions,
       openAIBackedProviderRoot(providerID) == nil {
        let raw = openAICompatibleProviderRoot(providerID)
        let camel = openAICompatibleCamelCase(raw)
        if camel != raw, providerOptions[camel] != nil {
            return camel
        }
    }
    return openAIBackedProviderRoot(providerID) ?? openAICompatibleProviderRoot(providerID)
}
public func openAICompatibleNamespacedProviderMetadata(_ metadata: [String: JSONValue], providerID: String, namespace: String? = nil) -> [String: JSONValue] {
    guard !metadata.isEmpty else { return [:] }
    return [namespace ?? openAICompatibleProviderMetadataNamespace(providerID): .object(metadata)]
}
public func openAICompatibleMergeProviderMetadata(_ source: [String: JSONValue], into target: inout [String: JSONValue]) {
    for (key, value) in source {
        if case let .object(existing) = target[key],
           case let .object(incoming) = value {
            target[key] = .object(existing.merging(incoming) { _, new in new })
        } else {
            target[key] = value
        }
    }
}
func openAICompatibleChatProviderMetadata(from raw: JSONValue, choice: JSONValue?, providerID: String, namespace: String? = nil) -> [String: JSONValue] {
    var metadata: [String: JSONValue] = [:]
    if let accepted = raw["usage"]?["completion_tokens_details"]?["accepted_prediction_tokens"] {
        metadata["acceptedPredictionTokens"] = accepted
    }
    if let rejected = raw["usage"]?["completion_tokens_details"]?["rejected_prediction_tokens"] {
        metadata["rejectedPredictionTokens"] = rejected
    }
    if let logprobs = choice?["logprobs"]?["content"] {
        metadata["logprobs"] = logprobs
    }
    return openAICompatibleNamespacedProviderMetadata(metadata, providerID: providerID, namespace: namespace)
}
func openAICompatibleCompletionProviderMetadata(from choice: JSONValue?, providerID: String, namespace: String? = nil) -> [String: JSONValue] {
    var metadata: [String: JSONValue] = [:]
    if let logprobs = choice?["logprobs"] {
        metadata["logprobs"] = logprobs
    }
    return openAICompatibleNamespacedProviderMetadata(metadata, providerID: providerID, namespace: namespace)
}
