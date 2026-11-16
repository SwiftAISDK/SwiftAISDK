import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

/// Seedream image model IDs published by `@ai-sdk/bytedance` 2.0.86.
public let byteDanceImageModelIDs = [
    "dola-seedream-5-0-pro-260628",
    "seedream-5-0-260128",
    "seedream-5-0-lite-260128",
    "seedream-4-5-251128",
    "seedream-4-0-250828"
]

/// ByteDance ModelArk Seedream image generation through `POST /images/generations`.
public final class ByteDanceImageModel: ImageModel, @unchecked Sendable {
    public let providerID = "bytedance.image"
    public let modelID: String
    /// Upstream generates one image per call; batches use `sequentialImageGeneration`.
    public let maxImagesPerCall = 1
    private let config: ByteDanceModelConfiguration

    public init(modelID: String, config: ByteDanceModelConfiguration) {
        self.modelID = modelID
        self.config = config
    }

    public var supportsFileInputs: Bool? {
        byteDanceImageModelIDs.contains(modelID) ? true : nil
    }

    public var supportsMaskInputs: Bool? {
        supportsFileInputs == true ? false : nil
    }

    public func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        var warnings: [AIWarning] = []
        if request.aspectRatio != nil {
            warnings.append(AIWarning(
                type: "unsupported",
                feature: "aspectRatio",
                message: "ByteDance does not support aspectRatio. Use `size` (e.g. \"2048x2048\" or a resolution level like \"2K\" via providerOptions) instead."
            ))
        }
        if request.seed != nil {
            warnings.append(AIWarning(type: "unsupported", feature: "seed"))
        }
        if request.mask != nil {
            warnings.append(AIWarning(
                type: "unsupported",
                feature: "mask",
                message: "ByteDance Seedream does not support a separate mask. Provide edit instructions in the prompt, optionally with markings on the input image."
            ))
        }
        let options = try byteDanceImageProviderOptions(request.providerOptions)

        var body: [String: JSONValue] = ["model": .string(modelID), "prompt": .string(request.prompt)]
        if request.files.count == 1 {
            body["image"] = .string(try convertImageModelFileToDataURI(request.files[0]))
        } else if !request.files.isEmpty {
            body["image"] = .array(try request.files.map { .string(try convertImageModelFileToDataURI($0)) })
        }
        if let size = request.size { body["size"] = .string(size) }
        for (key, value) in request.extraBody where key != "bytedance" { body[key] = value }
        if let options {
            if let value = options["watermark"], value != .null { body["watermark"] = value }
            if let value = options["outputFormat"], value != .null { body["output_format"] = value }
            if let value = options["size"], value != .null { body["size"] = value }
            if let value = options["sequentialImageGeneration"], value != .null { body["sequential_image_generation"] = value }
            if let value = options["maxImages"], value != .null { body["sequential_image_generation_options"] = ["max_images": value] }
            if let value = options["optimizePromptMode"], value != .null { body["optimize_prompt_options"] = ["mode": value] }
            for (key, value) in options where !byteDanceHandledImageOptions.contains(key) { body[key] = value }
        }
        body["response_format"] = "b64_json"

        let httpRequest = try config.request(path: "/images/generations", modelID: modelID, body: .object(body),
                                             headers: request.headers, abortSignal: request.abortSignal)
        let response = try await config.transport.send(httpRequest)
        guard (200..<300).contains(response.statusCode) else {
            var error = AIAPICallError(provider: providerID, url: httpRequest.url.absoluteString, requestBody: .object(body),
                                       statusCode: response.statusCode, responseHeaders: response.headers,
                                       responseBody: response.bodyText)
            error.message = byteDanceImageErrorMessage(response.body)
            throw AIError.apiCall(error)
        }
        let raw = try response.jsonValue()
        guard let data = raw["data"]?.arrayValue else {
            throw AIError.invalidResponse(provider: providerID, message: "ByteDance image response did not contain data.")
        }
        let images: [String] = try data.map { item in
            guard let b64 = item["b64_json"]?.stringValue else {
                throw AIError.invalidResponse(provider: providerID, message: "ByteDance image response item did not contain b64_json.")
            }
            return b64
        }
        return ImageGenerationResult(
            urls: [],
            base64Images: images,
            rawValue: raw,
            warnings: warnings,
            usage: byteDanceImageUsage(raw["usage"]),
            requestMetadata: imageGenerationRequestMetadata(request, body: .object(body)),
            responseMetadata: AIResponseMetadata(timestamp: Date(), modelID: modelID, headers: response.headers, body: raw)
        )
    }
}

private let byteDanceHandledImageOptions: Set<String> = [
    "watermark", "outputFormat", "size", "sequentialImageGeneration", "maxImages", "optimizePromptMode"
]

private func byteDanceImageProviderOptions(_ providerOptions: [String: JSONValue]) throws -> [String: JSONValue]? {
    guard let value = providerOptions["bytedance"], value != .null else { return nil }
    guard let options = value.objectValue else {
        throw AIError.invalidArgument(argument: "providerOptions.bytedance", message: "ByteDance provider options must be an object.")
    }
    func check(_ key: String, _ isValid: (JSONValue) -> Bool, _ message: String) throws {
        if let value = options[key], value != .null, !isValid(value) {
            throw AIError.invalidArgument(argument: "providerOptions.bytedance.\(key)", message: message)
        }
    }
    try check("watermark", { $0.boolValue != nil }, "ByteDance watermark must be a boolean.")
    try check("outputFormat", { ["png", "jpeg"].contains($0.stringValue ?? "") }, "ByteDance outputFormat must be one of png, jpeg.")
    try check("size", { $0.stringValue != nil }, "ByteDance size must be a string.")
    try check("sequentialImageGeneration", { ["auto", "disabled"].contains($0.stringValue ?? "") },
              "ByteDance sequentialImageGeneration must be one of auto, disabled.")
    try check("maxImages", { value in
        guard let number = value.doubleValue else { return false }
        return number > 0 && number.rounded() == number
    }, "ByteDance maxImages must be a positive integer.")
    try check("optimizePromptMode", { ["standard", "fast"].contains($0.stringValue ?? "") },
              "ByteDance optimizePromptMode must be one of standard, fast.")
    return options
}

private func byteDanceImageUsage(_ value: JSONValue?) -> TokenUsage? {
    guard let usage = value?.objectValue else { return nil }
    return TokenUsage(inputTokens: nil, outputTokens: usage["output_tokens"]?.intValue,
                      totalTokens: usage["total_tokens"]?.intValue)
}

private func byteDanceImageErrorMessage(_ body: Data) -> String? {
    guard let raw = try? decodeJSONBody(body) else { return nil }
    return raw["error"]?["message"]?.stringValue ?? raw["message"]?.stringValue ?? "Unknown error"
}
