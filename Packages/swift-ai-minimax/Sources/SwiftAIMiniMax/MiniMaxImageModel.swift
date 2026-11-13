import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// MiniMax H3 image generation and editing, using URL results with authenticated provider requests.
public final class MiniMaxImageModel: ImageModel, Sendable {
    public let providerID = "minimax.image"
    public let modelID: String
    public let supportsFileInputs: Bool? = true
    public let supportsMaskInputs: Bool? = false
    public let maxImagesPerCall = 10
    private let config: MiniMaxHTTPConfiguration

    init(modelID: String, config: MiniMaxHTTPConfiguration) { self.modelID = modelID; self.config = config }

    public func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        try request.abortSignal?.throwIfAborted()
        guard request.mask == nil else {
            throw AIError.invalidArgument(argument: "mask", message: "MiniMax image masks are not supported.")
        }
        let options = try miniMaxImageOptions(request.providerOptions["minimax"])
        var warnings: [AIWarning] = request.seed == nil ? [] : [.init(type: "unsupported", feature: "seed")]
        let editing = !request.files.isEmpty
        if editing, options["disablePromptEnhanced"] != nil {
            warnings.append(.init(type: "unsupported", feature: "disablePromptEnhanced", message: "MiniMax image edits always apply prompt enhancement."))
        }
        var body: [String: JSONValue] = ["model": .string(modelID), "prompt": .string(request.prompt),
            "n": request.count.map(JSONValue.init), "size": request.size.map(JSONValue.string),
            "aspect_ratio": request.aspectRatio.map(JSONValue.string), "response_format": "url",
            "area": options["area"], "output_format": options["outputFormat"], "output_compression": options["outputCompression"]].compactMapValues { $0 }
        if editing {
            body["images"] = .array(try request.files.map { .object(["image_url": .string(try convertImageModelFileToDataURI($0))]) })
        } else { body["disable_prompt_enhanced"] = options["disablePromptEnhanced"] }
        body.merge(request.extraBody) { _, explicit in explicit }
        let path = editing ? "/images/edits" : "/images/generations"
        let timestamp = Date()
        let result = try await config.sendJSONResponse(path: path, modelID: modelID, body: .object(body), headers: request.headers, abortSignal: request.abortSignal)
        try request.abortSignal?.throwIfAborted()
        guard let entries = result.json["data"]?.arrayValue else {
            throw AIError.invalidResponse(provider: providerID, message: "MiniMax image response is missing data.")
        }
        var images: [String] = [], metadata: [JSONValue] = []
        for (index, entry) in entries.enumerated() {
            if let error = entry["error"], error != .null {
                guard let message = error["message"]?.stringValue else {
                    throw AIError.invalidResponse(provider: providerID, message: "Invalid MiniMax per-image error.")
                }
                warnings.append(.init(type: "other", message: "Image \(index + 1) failed: \(message)"))
                continue
            }
            guard let url = entry["url"]?.stringValue else {
                throw AIError.invalidResponse(provider: providerID, message: "MiniMax returned an image without a URL.")
            }
            // Provider headers and bearer tokens must never reach image hosts.
            try request.abortSignal?.throwIfAborted()
            let downloaded = try await downloadURL(url, transport: config.transport, abortSignal: request.abortSignal, trustedOrigin: config.baseURL)
            try request.abortSignal?.throwIfAborted()
            guard (200..<300).contains(downloaded.statusCode) else { throw apiCallError(provider: providerID, response: downloaded) }
            images.append(downloaded.body.base64EncodedString())
            var image: [String: JSONValue] = ["size": entry["size"] ?? .null, "revisedPrompt": entry["revised_prompt"] ?? .null]
            image["outputFormat"] = result.json["output_format"].flatMap { value -> JSONValue? in value == .null ? nil : value }
            image["requestId"] = result.json["request_id"].flatMap { value -> JSONValue? in value == .null ? nil : value }
            if metadata.isEmpty, let usage = result.json["usage"], usage != .null { image["usage"] = usage }
            metadata.append(.object(image))
        }
        return ImageGenerationResult(urls: [], base64Images: images, rawValue: result.json, warnings: warnings,
            usage: result.json["usage"].flatMap { usage in
                guard usage != .null else { return nil }
                return TokenUsage(inputTokens: usage["input_tokens"]?.intValue, outputTokens: usage["output_tokens"]?.intValue,
                                  totalTokens: usage["total_tokens"]?.intValue, rawValue: usage)
            }, providerMetadata: ["minimax": .object(["images": .array(metadata)])],
            requestMetadata: .init(body: .object(body), headers: request.headers, url: config.baseURL + path),
            responseMetadata: .init(timestamp: timestamp, modelID: modelID, headers: result.response.headers))
    }
}

public struct MiniMaxImageModelOptions: Equatable, Sendable {
    public enum Area: String, Sendable { case oneK = "1K", twoK = "2K", fourK = "4K" }
    public enum OutputFormat: String, Sendable { case jpeg, jpg, png, webp }
    public var area: Area?
    public var disablePromptEnhanced: Bool?
    public var outputCompression: Int?
    public var outputFormat: OutputFormat?
    public init(area: Area? = nil, disablePromptEnhanced: Bool? = nil, outputCompression: Int? = nil, outputFormat: OutputFormat? = nil) {
        self.area = area; self.disablePromptEnhanced = disablePromptEnhanced; self.outputCompression = outputCompression; self.outputFormat = outputFormat
    }
    public var providerOptions: [String: JSONValue] {
        ["minimax": .object(["area": area.map { .string($0.rawValue) }, "disablePromptEnhanced": disablePromptEnhanced.map(JSONValue.bool),
            "outputCompression": outputCompression.map(JSONValue.init), "outputFormat": outputFormat.map { .string($0.rawValue) }])]
    }
}

private func miniMaxImageOptions(_ value: JSONValue?) throws -> [String: JSONValue] {
    guard let value, value != .null else { return [:] }
    guard let object = value.objectValue else { throw AIError.invalidArgument(argument: "providerOptions.minimax", message: "Image options must be an object.") }
    for (key, values) in [("area", ["1K", "2K", "4K"]), ("outputFormat", ["jpeg", "jpg", "png", "webp"])] {
        if let value = object[key], value != .null, !values.contains(value.stringValue ?? "") {
            throw AIError.invalidArgument(argument: "providerOptions.minimax.\(key)", message: "Invalid MiniMax image option.")
        }
    }
    if let value = object["disablePromptEnhanced"], value != .null, value.boolValue == nil {
        throw AIError.invalidArgument(argument: "providerOptions.minimax.disablePromptEnhanced", message: "Expected a boolean.")
    }
    if let value = object["outputCompression"], value != .null,
       value.doubleValue == nil || value.doubleValue?.rounded() != value.doubleValue || !(0...100).contains(value.doubleValue ?? -1) {
        throw AIError.invalidArgument(argument: "providerOptions.minimax.outputCompression", message: "Expected an integer from 0 to 100.")
    }
    return object.filter { $0.value != .null }
}
