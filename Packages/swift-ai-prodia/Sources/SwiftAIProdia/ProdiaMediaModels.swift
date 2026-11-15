import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class ProdiaLanguageModel: LanguageModel, @unchecked Sendable {
    public let providerID = "prodia.language"
    public let modelID: String
    private let config: ProdiaModelConfiguration

    public init(modelID: String, config: ProdiaModelConfiguration) {
        self.modelID = modelID
        self.config = config
    }

    public func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        try await prodiaGenerate(request).result
    }

    public func stream(_ request: LanguageModelRequest) -> AsyncThrowingStream<LanguageStreamPart, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let generated = try await prodiaGenerate(request)
                    let result = generated.result
                    continuation.yield(.streamStart(warnings: result.warnings))
                    continuation.yield(.responseMetadata(result.responseMetadata))
                    if !result.text.isEmpty {
                        let id = UUID().uuidString
                        continuation.yield(.textStart(id: id))
                        continuation.yield(.textDeltaPart(id: id, delta: result.text))
                        continuation.yield(.textEnd(id: id))
                    }
                    for file in generated.files {
                        continuation.yield(.file(file))
                    }
                    continuation.yield(.finishMetadata(reason: result.finishReason, usage: result.usage, providerMetadata: result.providerMetadata))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private func prodiaGenerate(_ request: LanguageModelRequest) async throws -> ProdiaLanguageGeneration {
        let options = try prodiaProviderOptions(from: request)
        let warnings = prodiaLanguageWarnings(for: request)
        var jobConfig: [String: JSONValue] = [
            "prompt": .string(prodiaPrompt(from: request.messages)),
            "include_messages": .bool(true)
        ]
        if let aspectRatio = options["aspectRatio"]?.stringValue ?? options["aspect_ratio"]?.stringValue {
            jobConfig["aspect_ratio"] = .string(aspectRatio)
        }

        let body: JSONValue = .object([
            "type": .string(modelID),
            "config": .object(jobConfig)
        ])
        var form = MultipartFormData()
        form.appendFile(name: "job", fileName: "job.json", mimeType: "application/json", data: try encodeJSONBody(body))
        if let input = try await prodiaInputImage(from: request.messages, transport: config.transport, abortSignal: request.abortSignal) {
            form.appendFile(name: "input", fileName: "input\(mediaExtension(input.mimeType))", mimeType: input.mimeType, data: input.data)
        }
        let payload = form.finalize()
        let response = try await config.transport.send(config.rawRequest(
            path: "/job?price=true",
            modelID: modelID,
            body: payload,
            contentType: "multipart/form-data; boundary=\(form.boundary)",
            headers: request.headers.mergingHeaders(["Accept": "multipart/form-data"]),
            abortSignal: request.abortSignal
        ))
        guard (200..<300).contains(response.statusCode) else {
            throw prodiaHTTPStatusError(provider: providerID, response: response)
        }
        let multipart = try parseMultipartResponse(response)
        let job = try prodiaValidatedJobResult(from: multipart, provider: providerID)
        let output = prodiaLanguageOutput(from: multipart)
        let text = output.text ?? ""
        let files = output.files
        let rawValue = multipartRawValue(multipart)
        return ProdiaLanguageGeneration(
            result: TextGenerationResult(
                text: text,
                finishReason: "stop",
                usage: TokenUsage(),
                files: files,
                providerMetadata: ["prodia": prodiaProviderMetadata(from: job)],
                rawValue: rawValue,
                warnings: warnings,
                responseMetadata: aiResponseMetadata(from: job, response: response, modelID: modelID)
            ),
            files: files
        )
    }
}

public final class ProdiaImageModel: ImageModel, @unchecked Sendable {
    public let providerID = "prodia.image"
    public let modelID: String
    /// Upstream `ProdiaImageModel.maxImagesPerCall`: each job yields one image.
    public let maxImagesPerCall = 1
    private let config: ProdiaModelConfiguration

    public init(modelID: String, config: ProdiaModelConfiguration) {
        self.modelID = modelID
        self.config = config
    }

    public func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        let options = try prodiaProviderOptions(from: request)
        var warnings: [AIWarning] = []
        var jobConfig: [String: JSONValue] = ["prompt": .string(request.prompt)]
        if let size = request.size {
            let parts = size.split(separator: "x", omittingEmptySubsequences: false).map(String.init)
            if parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]) {
                jobConfig["width"] = .number(Double(width))
                jobConfig["height"] = .number(Double(height))
            } else {
                warnings.append(AIWarning(
                    type: "unsupported",
                    feature: "size",
                    message: "Invalid size format: \(size). Expected format: WIDTHxHEIGHT (e.g., 1024x1024)"
                ))
            }
        }
        if let seed = request.seed {
            jobConfig["seed"] = .number(Double(seed))
        }
        jobConfig.merge(prodiaImageOptions(from: options)) { _, new in new }
        let body: JSONValue = .object([
            "type": .string(modelID),
            "config": .object(jobConfig)
        ])
        let response = try await config.transport.send(config.request(
            path: "/job?price=true",
            modelID: modelID,
            body: body,
            headers: request.headers.mergingHeaders(["Accept": "multipart/form-data; image/png"]),
            abortSignal: request.abortSignal
        ))
        guard (200..<300).contains(response.statusCode) else {
            throw prodiaHTTPStatusError(provider: providerID, response: response)
        }
        let multipart = try parseMultipartResponse(response)
        let job = try prodiaValidatedJobResult(from: multipart, provider: providerID)
        // Upstream createMultipartResponseHandler: a later matching part wins.
        let output = multipart.last { $0.name != "job" && ($0.name == "output" || $0.contentType?.hasPrefix("image/") == true) }
        guard let output else {
            throw AIError.invalidResponse(provider: providerID, message: "Prodia multipart response missing output image")
        }
        return ImageGenerationResult(
            urls: [],
            base64Images: [output.body.base64EncodedString()],
            rawValue: multipartRawValue(multipart),
            warnings: warnings,
            providerMetadata: ["prodia": .object(["images": .array([prodiaProviderMetadata(from: job)])])],
            requestMetadata: imageGenerationRequestMetadata(request, body: body),
            responseMetadata: aiResponseMetadata(from: job, response: response, modelID: modelID)
        )
    }
}

public final class ProdiaVideoModel: VideoModel, @unchecked Sendable {
    public let providerID = "prodia.video"
    public let modelID: String
    /// Upstream `ProdiaVideoModel.maxVideosPerCall`: each job yields one video.
    public let maxVideosPerCall = 1
    private let config: ProdiaModelConfiguration

    public init(modelID: String, config: ProdiaModelConfiguration) {
        self.modelID = modelID
        self.config = config
    }

    public func generateVideo(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult {
        let options = try prodiaProviderOptions(from: request)
        var jobConfig: [String: JSONValue] = ["prompt": .string(request.prompt)]
        if let seed = request.seed {
            jobConfig["seed"] = .number(Double(seed))
        } else if let seed = options["seed"] {
            jobConfig["seed"] = seed
        }
        if let resolution = options["resolution"] { jobConfig["resolution"] = resolution }
        let body: JSONValue = .object([
            "type": .string(modelID),
            "config": .object(jobConfig)
        ])
        let response: AIHTTPResponse
        if let image = request.image {
            let input = try await prodiaVideoInputImage(from: image, transport: config.transport, abortSignal: request.abortSignal)
            var form = MultipartFormData()
            form.appendFile(name: "job", fileName: "job.json", mimeType: "application/json", data: try encodeJSONBody(body))
            form.appendFile(name: "input", fileName: "input\(mediaExtension(input.mimeType))", mimeType: input.mimeType, data: input.data)
            let payload = form.finalize()
            response = try await config.transport.send(config.rawRequest(
                path: "/job?price=true",
                modelID: modelID,
                body: payload,
                contentType: "multipart/form-data; boundary=\(form.boundary)",
                headers: request.headers.mergingHeaders(["Accept": "multipart/form-data; video/mp4"]),
                abortSignal: request.abortSignal
            ))
        } else {
            response = try await config.transport.send(config.request(
                path: "/job?price=true",
                modelID: modelID,
                body: body,
                headers: request.headers.mergingHeaders(["Accept": "multipart/form-data; video/mp4"]),
                abortSignal: request.abortSignal
            ))
        }
        guard (200..<300).contains(response.statusCode) else {
            throw prodiaHTTPStatusError(provider: providerID, response: response)
        }
        let multipart = try parseMultipartResponse(response)
        let job = try prodiaValidatedJobResult(from: multipart, provider: providerID)
        // Mirrors upstream createVideoMultipartResponseHandler: a later matching
        // part replaces an earlier one, and a named `output` part keeps the
        // previous media type (default `video/mp4`) unless it declares `video/*`.
        var videoBytes: Data?
        var videoMediaType = "video/mp4"
        for part in multipart where part.name != "job" {
            let partContentType = part.contentType ?? ""
            if part.name == "output" {
                videoBytes = part.body
                if partContentType.hasPrefix("video/") {
                    videoMediaType = partContentType
                }
            } else if partContentType.hasPrefix("video/") {
                videoBytes = part.body
                videoMediaType = partContentType
            }
        }
        guard let videoBytes else {
            throw AIError.invalidResponse(provider: providerID, message: "Prodia multipart response missing output video")
        }
        return VideoGenerationResult(
            urls: [],
            base64Videos: [videoBytes.base64EncodedString()],
            operationID: job["id"]?.stringValue,
            mediaType: videoMediaType,
            rawValue: multipartRawValue(multipart),
            providerMetadata: ["prodia": .object(["videos": .array([prodiaProviderMetadata(from: job)])])],
            requestMetadata: videoGenerationRequestMetadata(request, body: body),
            responseMetadata: aiResponseMetadata(from: job, response: response, modelID: modelID)
        )
    }
}