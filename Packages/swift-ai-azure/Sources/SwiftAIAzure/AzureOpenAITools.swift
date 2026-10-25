import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible
import SwiftAIDeepSeek


public enum AzureOpenAITools {
    public static func codeInterpreter(container: JSONValue? = nil) -> JSONValue {
        OpenAITools.codeInterpreter(container: container)
    }

    public static func fileSearch(vectorStoreIDs: [String], maxNumResults: Int? = nil, ranking: JSONValue? = nil, filters: JSONValue? = nil) -> JSONValue {
        OpenAITools.fileSearch(vectorStoreIDs: vectorStoreIDs, maxNumResults: maxNumResults, ranking: ranking, filters: filters)
    }

    /// Source-compatible image-generation tool factory retained from 1.5.x.
    public static func imageGeneration(
        background: String? = nil,
        inputFidelity: String? = nil,
        inputImageMask: JSONValue? = nil,
        model: String? = nil,
        moderation: String? = nil,
        outputCompression: Int? = nil,
        outputFormat: String? = nil,
        partialImages: Int? = nil,
        quality: String? = nil,
        size: String? = nil
    ) -> JSONValue {
        imageGeneration(
            action: nil,
            background: background,
            inputFidelity: inputFidelity,
            inputImageMask: inputImageMask,
            model: model,
            moderation: moderation,
            outputCompression: outputCompression,
            outputFormat: outputFormat,
            partialImages: partialImages,
            quality: quality,
            size: size
        )
    }

    public static func imageGeneration(
        action: String? = nil,
        background: String? = nil,
        inputFidelity: String? = nil,
        inputImageMask: JSONValue? = nil,
        model: String? = nil,
        moderation: String? = nil,
        outputCompression: Int? = nil,
        outputFormat: String? = nil,
        partialImages: Int? = nil,
        quality: String? = nil,
        size: String? = nil
    ) -> JSONValue {
        OpenAITools.imageGeneration(
            action: action,
            background: background,
            inputFidelity: inputFidelity,
            inputImageMask: inputImageMask,
            model: model,
            moderation: moderation,
            outputCompression: outputCompression,
            outputFormat: outputFormat,
            partialImages: partialImages,
            quality: quality,
            size: size
        )
    }

    public static func webSearch(filters: JSONValue? = nil, externalWebAccess: Bool? = nil, searchContextSize: String? = nil, userLocation: JSONValue? = nil) -> JSONValue {
        OpenAITools.webSearch(filters: filters, externalWebAccess: externalWebAccess, searchContextSize: searchContextSize, userLocation: userLocation)
    }

    @available(*, deprecated, message: "Use webSearch instead.")
    public static func webSearchPreview(searchContextSize: String? = nil, userLocation: JSONValue? = nil) -> JSONValue {
        OpenAITools.webSearchPreview(searchContextSize: searchContextSize, userLocation: userLocation)
    }
}