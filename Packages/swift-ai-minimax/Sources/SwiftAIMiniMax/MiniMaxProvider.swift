import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIAnthropic


public struct MiniMaxProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var videoBaseURL: String?
    public var headers: [String: String]
    public var environment: [String: String]?
    public var transport: any AITransport

    public init(
        apiKey: String? = nil,
        baseURL: String? = nil,
        videoBaseURL: String? = nil,
        headers: [String: String] = [:],
        environment: [String: String]? = nil,
        transport: any AITransport = URLSessionTransport.shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.videoBaseURL = videoBaseURL
        self.headers = headers
        self.environment = environment
        self.transport = transport
    }

    func environmentValue(_ name: String) -> String? {
        if let environment { return environment[name] }
        return SwiftAITransport.environmentValue([name])
    }
}

public final class MiniMaxProvider: AIProvider, @unchecked Sendable {
    public let providerID = "minimax"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .video]

    private let config: MiniMaxHTTPConfiguration
    private let videoConfig: MiniMaxHTTPConfiguration

    public init(settings: MiniMaxProviderSettings = MiniMaxProviderSettings()) throws {
        let apiKey = settings.apiKey ?? settings.environmentValue("MINIMAX_API_KEY")
        guard let apiKey else {
            throw AIError.missingAPIKey(
                provider: providerID,
                environmentVariables: ["MINIMAX_API_KEY"]
            )
        }

        var languageHeaders = normalizeHeaders(settings.headers)
        languageHeaders["anthropic-version"] = languageHeaders["anthropic-version"] ?? "2023-06-01"
        languageHeaders["x-api-key"] = languageHeaders["x-api-key"] ?? apiKey
        languageHeaders = withUserAgentSuffix(languageHeaders, "ai-sdk-minimax/3.0.65")

        config = MiniMaxHTTPConfiguration(
            providerID: "minimax.messages",
            baseURL: settings.baseURL ?? "https://api.minimax.io/anthropic/v1",
            headers: languageHeaders,
            transport: settings.transport
        )

        var videoHeaders = normalizeHeaders(settings.headers)
        videoHeaders["authorization"] = videoHeaders["authorization"] ?? "Bearer \(apiKey)"
        videoHeaders = withUserAgentSuffix(videoHeaders, "ai-sdk-minimax/3.0.65")
        videoConfig = MiniMaxHTTPConfiguration(
            providerID: "minimax.video",
            baseURL: settings.videoBaseURL ?? "https://api.minimax.io",
            headers: videoHeaders,
            transport: settings.transport
        )
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        AnthropicLanguageModel(
            modelID: modelID,
            config: config.anthropicConfiguration,
            supportedURLs: miniMaxSupportsM31Features(modelID) ? [
                "image/*": [AISupportedURLPattern { $0.hasPrefix("https://") || $0.hasPrefix("http://") }],
                "video/*": [AISupportedURLPattern { $0.hasPrefix("https://") || $0.hasPrefix("http://") }]
            ] : [:]
        )
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        MiniMaxVideoModel(modelID: modelID, config: videoConfig)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }
}

/// MiniMax M3.1 and later reasoning controls. Explicit effort wins over `reasoning`.
public struct MiniMaxLanguageModelOptions: Equatable, Sendable {
    public enum Effort: String, Equatable, Sendable { case low, medium, high, xhigh, max }
    public enum Thinking: String, Equatable, Sendable { case adaptive, disabled }
    public var effort: Effort?
    public var thinking: Thinking?
    public init(effort: Effort? = nil, thinking: Thinking? = nil) {
        self.effort = effort
        self.thinking = thinking
    }
    public var providerOptions: [String: JSONValue] {
        ["minimax": .object([
            "effort": effort.map { .string($0.rawValue) },
            "thinking": thinking.map { .object(["type": .string($0.rawValue)]) }
        ])]
    }
}

/// Image processing controls on MiniMax M3.1 and later content parts.
public struct MiniMaxImagePartOptions: Equatable, Sendable {
    public enum Detail: String, Equatable, Sendable { case low, `default`, high }
    public var detail: Detail?
    public init(detail: Detail? = nil) { self.detail = detail }
    public var providerOptions: [String: JSONValue] {
        ["minimax": .object(["detail": detail.map { .string($0.rawValue) }])]
    }
}

/// Video sampling controls on MiniMax M3.1 and later content parts.
public struct MiniMaxVideoPartOptions: Equatable, Sendable {
    /// Frames per second, from 0.2 through 5. Omit to use the server default.
    public var fps: Double?
    public init(fps: Double? = nil) { self.fps = fps }
    public var providerOptions: [String: JSONValue] {
        ["minimax": .object(["fps": fps.map(JSONValue.number)])]
    }
}

/// Stable prompt-prefix cache markers; a marker does not guarantee a cache hit.
public struct MiniMaxCacheControlOptions: Equatable, Sendable {
    public enum CacheControl: String, Equatable, Sendable { case ephemeral }
    public var cacheControl: CacheControl?
    public init(cacheControl: CacheControl? = nil) { self.cacheControl = cacheControl }
    public var providerOptions: [String: JSONValue] {
        ["minimax": .object(["cacheControl": cacheControl.map { .object(["type": .string($0.rawValue)]) }])]
    }
}

func miniMaxSupportsM31Features(_ modelID: String) -> Bool {
    guard let match = modelID.range(
        of: #"^minimax-m([0-9]+)(?:\.([0-9]+))?(?:\.[0-9]+)*(?:-|$)"#,
        options: [.regularExpression, .caseInsensitive]
    ) else { return false }
    let version = modelID[match].lowercased().dropFirst("minimax-m".count).split(separator: "-", maxSplits: 1)[0]
    let components = version.split(separator: ".")
    // Lexical numeric comparison also handles IDs with components too large for Int.
    func magnitude(_ value: Substring) -> String {
        let digits = value.drop(while: { $0 == "0" })
        return digits.isEmpty ? "0" : String(digits)
    }
    let major = magnitude(components[0])
    if major.count > 1 || major > "3" { return true }
    return major == "3" && components.count > 1 && magnitude(components[1]) != "0"
}

func miniMaxReasoningRequest(
    _ request: LanguageModelRequest,
    modelID: String,
    warnings: inout [AIWarning]
) throws -> LanguageModelRequest {
    if let options = request.providerOptions["minimax"], options != .null, options.objectValue == nil {
        throw AIError.invalidArgument(argument: "providerOptions.minimax", message: "MiniMax provider options must be an object.")
    }
    guard let reasoning = request.reasoning,
          reasoning != "provider-default",
          request.providerOptions["minimax"]?["effort"] == nil || request.providerOptions["minimax"]?["effort"] == .null,
          request.providerOptions["anthropic"]?["effort"] == nil || request.providerOptions["anthropic"]?["effort"] == .null else {
        return try miniMaxValidatedEffort(request)
    }
    let effort: String?
    if reasoning == "none" {
        effort = "low"
        warnings.append(AIWarning(type: "compatibility", feature: "reasoning", message: "reasoning 'none' is not supported by \(modelID); it always reasons. Using effort 'low' to minimize thinking instead."))
    } else if reasoning == "minimal" {
        effort = "low"
        warnings.append(AIWarning(type: "compatibility", feature: "reasoning", message: "reasoning \"minimal\" is not directly supported by this model. mapped to effort \"low\"."))
    } else if ["low", "medium", "high", "xhigh", "max"].contains(reasoning) {
        effort = reasoning
    } else {
        effort = nil
        warnings.append(AIWarning(type: "unsupported", feature: "reasoning", message: "reasoning \"\(reasoning)\" is not supported by this model."))
    }
    var prepared = request
    prepared.reasoning = nil
    var options = prepared.providerOptions["minimax"]?.objectValue ?? [:]
    if let effort { options["effort"] = .string(effort) }
    prepared.providerOptions["minimax"] = .object(options)
    return try miniMaxValidatedEffort(prepared)
}

private func miniMaxValidatedEffort(_ request: LanguageModelRequest) throws -> LanguageModelRequest {
    for namespace in ["anthropic", "minimax"] {
        if let value = request.providerOptions[namespace]?["effort"],
           !["low", "medium", "high", "xhigh", "max"].contains(value.stringValue) {
            throw AIError.invalidArgument(
                argument: "providerOptions.\(namespace).effort",
                message: "MiniMax effort must be low, medium, high, xhigh, or max."
            )
        }
    }
    return request
}

/// Compatible-media conversion is stateless, so one model can serve concurrent calls.
func miniMaxMediaContent(_ part: AIContentPart) throws -> JSONValue? {
    let type: String
    var source: [String: JSONValue]
    switch part {
    case let .imageURL(url, _):
        // Preserve the shared Swift prompt representation for hosted PDF documents.
        guard !url.lowercased().contains(".pdf") else { return nil }
        type = "image"
        source = ["type": "url", "url": .string(url)]
    case let .data(mediaType, data, _), let .file(mediaType, data, _, _):
        type = topLevelMediaType(mediaType)
        guard type == "image" || type == "video" else { return nil }
        source = ["type": "base64", "media_type": .string(try resolveFullMediaType(mediaType: mediaType, data: data)), "data": .string(data.base64EncodedString())]
    case let .providerReference(mediaType, reference, _, _):
        type = topLevelMediaType(mediaType)
        guard type == "image" || type == "video" else { return nil }
        guard type == "video" else {
            throw AIError.invalidArgument(argument: "messages", message: "MiniMax image file references are not supported.")
        }
        if reference["minimax"] == nil,
           let hostedURL = reference["openaiCompatible"],
           let parsedURL = URL(string: hostedURL),
           ["http", "https"].contains(parsedURL.scheme?.lowercased() ?? ""),
           parsedURL.host != nil {
            source = ["type": "url", "url": .string(hostedURL)]
        } else {
            let fileID = try resolveProviderReference(reference, provider: "minimax")
            source = ["type": "url", "url": .string(fileID.hasPrefix("mm_file://") ? fileID : "mm_file://\(fileID)")]
        }
    default: return nil
    }
    if let value = part.providerMetadata["minimax"], value != .null {
        guard let options = value.objectValue else {
            throw AIError.invalidArgument(argument: "providerOptions.minimax", message: "MiniMax media options must be an object.")
        }
        if type == "image", let detail = options["detail"] {
            guard let detail = detail.stringValue, ["low", "default", "high"].contains(detail) else {
                throw AIError.invalidArgument(argument: "providerOptions.minimax.detail", message: "Image detail must be low, default, or high.")
            }
            source["detail"] = .string(detail)
        }
        if type == "video", let value = options["fps"] {
            guard let fps = value.doubleValue, fps.isFinite, (0.2...5).contains(fps) else {
                throw AIError.invalidArgument(argument: "providerOptions.minimax.fps", message: "Video fps must be a finite number from 0.2 through 5.")
            }
            source["fps"] = .number(fps)
        }
    }
    return .object(["type": .string(type), "source": .object(source)])
}
/// MiniMax Messages differences used by native and legacy hosting adapters.
public func miniMaxRequestPolicy(modelID: String) -> AnthropicRequestPolicy {
                var policy = AnthropicRequestPolicy()
                if miniMaxSupportsM31Features(modelID) {
                    policy.metadataNamespace = "minimax"
                    policy.maximumTemperature = 2
                    policy.supportsSamplingWithThinking = true
                    policy.prepareRequest = { try miniMaxReasoningRequest($0, modelID: $1, warnings: &$2) }
                    policy.userMediaContent = miniMaxMediaContent
                }
                return policy
}

public extension AIProviders {
    static func miniMax(configuration: MiniMaxProviderSettings) throws -> MiniMaxProvider { try MiniMaxProvider(settings: configuration) }
}

public extension MiniMaxProvider {
    convenience init(configuration: MiniMaxProviderSettings) throws { try self.init(settings: configuration) }
}
