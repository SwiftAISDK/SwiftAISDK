import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
public func openAIImageProviderMetadata(from raw: JSONValue, providerID: String, openAIBackedProviderRoot: String? = nil) -> [String: JSONValue] {
    guard openAIBackedProviderRoot != nil || isOpenAIBackedProvider(providerID) else { return [:] }
    let images = raw["data"]?.arrayValue ?? []
    return [
        "openai": .object([
            "images": .array(images.enumerated().map { index, image in
                var metadata: [String: JSONValue] = [:]
                if let revisedPrompt = image["revised_prompt"]?.stringValue, !revisedPrompt.isEmpty {
                    metadata["revisedPrompt"] = .string(revisedPrompt)
                }
                if let created = raw["created"] {
                    metadata["created"] = created
                }
                if let size = raw["size"] {
                    metadata["size"] = size
                }
                if let quality = raw["quality"] {
                    metadata["quality"] = quality
                }
                if let background = raw["background"] {
                    metadata["background"] = background
                }
                if let outputFormat = raw["output_format"] {
                    metadata["outputFormat"] = outputFormat
                }
                metadata.merge(openAIImageTokenDetails(from: raw["usage"]?["input_tokens_details"], index: index, total: images.count)) { _, new in new }
                return .object(metadata)
            })
        ])
    ]
}
func openAIImageTokenDetails(from details: JSONValue?, index: Int, total: Int) -> [String: JSONValue] {
    guard total > 0 else { return [:] }
    var metadata: [String: JSONValue] = [:]
    if let imageTokens = details?["image_tokens"]?.intValue {
        metadata["imageTokens"] = .number(Double(openAIImageDistributedTokens(imageTokens, index: index, total: total)))
    }
    if let textTokens = details?["text_tokens"]?.intValue {
        metadata["textTokens"] = .number(Double(openAIImageDistributedTokens(textTokens, index: index, total: total)))
    }
    return metadata
}
func openAIImageDistributedTokens(_ tokens: Int, index: Int, total: Int) -> Int {
    let base = tokens / total
    let remainder = tokens - base * (total - 1)
    return index == total - 1 ? remainder : base
}

public func openAIImageSupportsFileInputs(_ modelID: String) -> Bool? {
    if ["dall-e-2", "gpt-image-1", "gpt-image-1-mini", "gpt-image-1.5", "gpt-image-2", "gpt-image-2.5-flare", "gpt-image-2.5-flare-2026-09-08", "gpt-image-2.5-sunburst", "gpt-image-2.5-sunburst-2026-09-08", "chatgpt-image-latest"].contains(modelID) { return true }
    if modelID == "dall-e-3" { return false }
    return nil
}
