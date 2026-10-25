import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class OpenAICompatibleEmbeddingModel: EmbeddingModel, @unchecked Sendable {
    public let providerID: String
    public let modelID: String
    private let config: OpenAICompatibleModelConfiguration
    public var maxEmbeddingsPerCall: Int? { config.maxEmbeddingsPerCall ?? 2048 }
    public var maxInputBytesPerCall: Int? {
        isOpenAIBackedProvider(providerID, config: config) ? 300_000 : nil
    }

    public init(modelID: String, config: OpenAICompatibleModelConfiguration) {
        self.providerID = config.providerID
        self.modelID = modelID
        self.config = config
    }

    public func embed(_ request: EmbeddingRequest) async throws -> EmbeddingResult {
        let maxEmbeddingsPerCall = maxEmbeddingsPerCall ?? 2048
        guard request.values.count <= maxEmbeddingsPerCall else {
            throw AITooManyEmbeddingValuesForCallError(
                provider: providerID,
                modelID: modelID,
                maxEmbeddingsPerCall: maxEmbeddingsPerCall,
                values: request.values
            )
        }
        let warnings = isOpenAIBackedProvider(providerID, config: config)
            ? []
            : (config.usesGenericOpenAICompatibleProviderOptions
                ? openAICompatibleProviderOptionWarnings(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, includeCompatibilityNamespace: true)
                : openAICompatibleProviderOptionWarnings(from: request.extraBody, providerID: providerID, includeCompatibilityNamespace: true))

        var body: [String: JSONValue] = [
            "model": .string(modelID),
            "input": .array(request.values)
        ]
        if let dimensions = request.dimensions { body["dimensions"] = .number(Double(dimensions)) }
        if isOpenAIBackedProvider(providerID, config: config) || openAICompatibleProviderSurface(providerID) == "embedding" {
            body["encoding_format"] = .string("float")
        }
        let extraBody: [String: JSONValue]
        if isOpenAIBackedProvider(providerID, config: config) {
            extraBody = openAIProviderOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, providerRoot: config.openAIBackedProviderRoot)
        } else if config.usesGenericOpenAICompatibleProviderOptions {
            extraBody = openAICompatibleProviderOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, includeCompatibilityNamespace: true)
        } else {
            extraBody = openAICompatibleProviderOptions(from: request.extraBody, providerID: providerID, includeCompatibilityNamespace: true)
        }
        body.merge(extraBody) { _, new in new }

        let response = try await config.sendJSONResponse(path: "/embeddings", modelID: modelID, body: .object(body), headers: request.headers, abortSignal: request.abortSignal)
        let raw = response.json
        guard case let .array(data) = raw["data"] else {
            throw AIError.invalidResponse(provider: providerID, message: "No embedding data found.")
        }

        let embeddings = data.compactMap { item -> [Double]? in
            guard case let .array(values) = item["embedding"] else { return nil }
            return values.compactMap(\.doubleValue)
        }
        return EmbeddingResult(
            embeddings: embeddings,
            usage: tokenUsage(from: raw),
            rawValue: raw,
            warnings: warnings,
            providerMetadata: raw["providerMetadata"]?.objectValue ?? [:],
            requestMetadata: AIRequestMetadata(body: .object(body), headers: request.headers),
            responseMetadata: openAICompatibleResponseMetadata(from: raw, response: response.response, modelID: modelID)
        )
    }
}

public final class OpenAICompatibleImageModel: ImageModel, @unchecked Sendable {
    public let providerID: String
    public let modelID: String
    private let config: OpenAICompatibleModelConfiguration
    public var supportsFileInputs: Bool? { config.imageSupportsFileInputs?(modelID) }
    public var supportsMaskInputs: Bool? { config.imageSupportsMaskInputs?(modelID) }
    private var maxImagesPerCall: Int {
        config.maximumImages?(modelID) ?? 10
    }

    public init(modelID: String, config: OpenAICompatibleModelConfiguration) {
        self.providerID = config.providerID
        self.modelID = modelID
        self.config = config
    }

    public func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        if let count = request.count, count > maxImagesPerCall {
            throw AIError.invalidArgument(argument: "count", message: "OpenAI-compatible image models support at most \(maxImagesPerCall) image(s) per call.")
        }
        let warnings = openAICompatibleImageWarnings(from: request, providerID: providerID, openAIBackedProviderRoot: config.openAIBackedProviderRoot, usesGenericProviderOptions: config.usesGenericOpenAICompatibleProviderOptions)
        if !request.files.isEmpty {
            return try await editImage(request, warnings: warnings)
        }

        var body: [String: JSONValue] = [
            "model": .string(modelID),
            "prompt": .string(request.prompt)
        ]
        if let size = request.size { body["size"] = .string(size) }
        if let count = request.count { body["n"] = .number(Double(count)) }
        let imageOptions: [String: JSONValue]
        if isOpenAIBackedProvider(providerID, config: config) {
            imageOptions = openAIImageOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, providerRoot: config.openAIBackedProviderRoot)
        } else if config.usesGenericOpenAICompatibleProviderOptions {
            imageOptions = openAICompatibleProviderOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, includeCompatibilityNamespace: false)
        } else {
            imageOptions = openAICompatibleProviderOptions(from: request.extraBody, providerID: providerID, includeCompatibilityNamespace: false)
        }
        body.merge(imageOptions) { _, new in new }
        if isOpenAIBackedProvider(providerID, config: config), body["response_format"] == nil, !(config.imageHasDefaultResponseFormat?(modelID) ?? true) {
            body["response_format"] = .string("b64_json")
        }

        let httpRequest = try config.request(path: "/images/generations", modelID: modelID, body: .object(body), headers: request.headers, abortSignal: request.abortSignal)
        let response = try await config.transport.send(httpRequest)
        guard (200..<300).contains(response.statusCode) else { throw config.httpStatusError(response) }
        let raw = try response.jsonValue()
        guard case let .array(data) = raw["data"] else {
            throw AIError.invalidResponse(provider: providerID, message: "No image data found.")
        }
        return ImageGenerationResult(
            urls: data.compactMap { $0["url"]?.stringValue },
            base64Images: try await resolvedImages(data, request: httpRequest),
            rawValue: raw,
            warnings: warnings,
            usage: tokenUsage(from: raw),
            providerMetadata: config.imageMetadata?(raw) ?? [:],
            requestMetadata: imageGenerationRequestMetadata(request, body: .object(body)),
            responseMetadata: openAICompatibleResponseMetadata(from: raw, response: response, modelID: modelID)
        )
    }

    private func editImage(_ request: ImageGenerationRequest, warnings: [AIWarning]) async throws -> ImageGenerationResult {
        var form = MultipartFormData()
        form.appendField(name: "model", value: modelID)
        form.appendField(name: "prompt", value: request.prompt)
        for file in request.files {
            let resolved = try await openAICompatibleResolveImageFile(
                file,
                providerID: providerID,
                transport: config.transport,
                abortSignal: request.abortSignal
            )
            form.appendFile(name: "image", fileName: resolved.fileName, mimeType: resolved.mediaType, data: resolved.data)
        }
        if let mask = request.mask {
            let resolved = try await openAICompatibleResolveImageFile(
                mask,
                providerID: providerID,
                transport: config.transport,
                abortSignal: request.abortSignal
            )
            form.appendFile(name: "mask", fileName: resolved.fileName, mimeType: resolved.mediaType, data: resolved.data)
        }
        if let count = request.count {
            form.appendField(name: "n", value: String(count))
        }
        if let size = request.size {
            form.appendField(name: "size", value: size)
        }

        let extraBody: [String: JSONValue]
        if isOpenAIBackedProvider(providerID, config: config) {
            extraBody = openAIImageOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, providerRoot: config.openAIBackedProviderRoot)
        } else if config.usesGenericOpenAICompatibleProviderOptions {
            extraBody = openAICompatibleProviderOptions(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, includeCompatibilityNamespace: false)
        } else {
            extraBody = openAICompatibleProviderOptions(from: request.extraBody, providerID: providerID, includeCompatibilityNamespace: false)
        }
        for (key, value) in extraBody {
            if case let .array(items) = value {
                for item in items {
                    if let scalar = jsonScalarString(item) {
                        form.appendField(name: key, value: scalar)
                    }
                }
            } else if let scalar = jsonScalarString(value) {
                form.appendField(name: key, value: scalar)
            }
        }

        let httpRequest = try config.rawRequest(
                path: "/images/edits",
                modelID: modelID,
                body: form.finalize(),
                contentType: "multipart/form-data; boundary=\(form.boundary)",
                headers: request.headers,
                abortSignal: request.abortSignal
            )
        let response = try await config.transport.send(httpRequest)
        guard (200..<300).contains(response.statusCode) else {
            throw apiCallError(provider: providerID, response: response)
        }
        let raw = try response.jsonValue()
        guard case let .array(data) = raw["data"] else {
            throw AIError.invalidResponse(provider: providerID, message: "No image data found.")
        }
        return ImageGenerationResult(
            urls: data.compactMap { $0["url"]?.stringValue },
            base64Images: try await resolvedImages(data, request: httpRequest),
            rawValue: raw,
            warnings: warnings,
            usage: tokenUsage(from: raw),
            providerMetadata: config.imageMetadata?(raw) ?? [:],
            requestMetadata: imageGenerationRequestMetadata(request),
            responseMetadata: openAICompatibleResponseMetadata(from: raw, response: response, modelID: modelID)
        )
    }

    private func resolvedImages(_ data: [JSONValue], request: AIHTTPRequest) async throws -> [String] {
        guard !isOpenAIBackedProvider(providerID, config: config) else {
            return data.compactMap { $0["b64_json"]?.stringValue }
        }
        for image in data {
            for key in ["b64_json", "url"] {
                if let value = image[key], value != .null, value.stringValue == nil {
                    throw AIError.invalidResponse(provider: providerID, message: "Image response \(key) must be a string or null.")
                }
            }
            guard image["b64_json"]?.stringValue != nil || image["url"]?.stringValue != nil else {
                throw AIError.invalidResponse(provider: providerID, message: "Expected b64_json or url in the image response.")
            }
        }
        // Preserve upstream's base64-only responses verbatim. Mixed responses
        // normalize to the local base64 array in the original image order.
        if data.allSatisfy({ $0["b64_json"]?.stringValue != nil }) {
            return data.compactMap { $0["b64_json"]?.stringValue }
        }
        var images: [String] = []
        for image in data {
            if let encoded = image["b64_json"]?.stringValue {
                guard Data(base64Encoded: encoded) != nil else {
                    throw AIError.invalidResponse(provider: providerID, message: "Invalid base64 image data.")
                }
                images.append(encoded)
                continue
            }
            guard let url = image["url"]?.stringValue else {
                throw AIError.invalidResponse(provider: providerID, message: "Expected b64_json or url in the image response.")
            }
            let response = try await downloadURL(
                url, transport: config.transport, headers: request.headers,
                abortSignal: request.abortSignal,
                trustedOrigin: request.url.absoluteString,
                credentialedOrigin: request.url.absoluteString
            )
            guard (200..<300).contains(response.statusCode) else { throw apiCallError(provider: providerID, response: response) }
            images.append(response.body.base64EncodedString())
        }
        return images
    }
}

func openAICompatibleImageWarnings(from request: ImageGenerationRequest, providerID: String, openAIBackedProviderRoot: String? = nil, usesGenericProviderOptions: Bool = false) -> [AIWarning] {
    guard openAIBackedProviderRoot == nil, !isOpenAIBackedProvider(providerID) else { return [] }
    var warnings = usesGenericProviderOptions
        ? openAICompatibleProviderOptionWarnings(providerOptions: request.providerOptions, extraBody: request.extraBody, providerID: providerID, includeCompatibilityNamespace: false)
        : openAICompatibleProviderOptionWarnings(from: request.extraBody, providerID: providerID, includeCompatibilityNamespace: false)
    if request.aspectRatio != nil {
        warnings.append(AIWarning(
            type: "unsupported",
            feature: "aspectRatio",
            message: "This model does not support aspect ratio. Use `size` instead."
        ))
    }
    if request.seed != nil {
        warnings.append(AIWarning(type: "unsupported", feature: "seed"))
    }
    return warnings
}

struct OpenAICompatibleResolvedImageFile {
    var data: Data
    var mediaType: String
    var fileName: String
}

func openAICompatibleResolveImageFile(
    _ file: ImageInputFile,
    providerID: String,
    transport: AITransport,
    abortSignal: AIAbortSignal? = nil
) async throws -> OpenAICompatibleResolvedImageFile {
    if let data = file.data {
        let mediaType = file.mediaType ?? "application/octet-stream"
        return OpenAICompatibleResolvedImageFile(data: data, mediaType: mediaType, fileName: file.fileName ?? openAICompatibleDefaultFileName(mediaType: mediaType))
    }

    guard let url = file.url else {
        throw AIError.invalidResponse(provider: providerID, message: "Image file must contain data or a URL.")
    }
    let response = try await downloadURL(
        url,
        transport: transport,
        abortSignal: abortSignal
    )
    guard (200..<300).contains(response.statusCode) else {
        throw apiCallError(provider: providerID, response: response)
    }
    let mediaType = file.mediaType
        ?? response.headers["content-type"]
        ?? response.headers["Content-Type"]
        ?? "application/octet-stream"
    return OpenAICompatibleResolvedImageFile(data: response.body, mediaType: mediaType, fileName: file.fileName ?? openAICompatibleDefaultFileName(mediaType: mediaType))
}

func openAICompatibleDefaultFileName(mediaType: String) -> String {
    switch mediaType {
    case "image/png": "image.png"
    case "image/jpeg", "image/jpg": "image.jpg"
    case "image/webp": "image.webp"
    default: "image"
    }
}

