import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible


public let gmiCloudProviderVersion = "3.0.49"

public func createGMICloud(configuration settings: GMICloudProviderSettings) throws -> GMICloudProvider {
    try GMICloudProvider(configuration: settings)
}

/// GMI Cloud chat completions over its OpenAI-compatible API.
public final class GMICloudProvider: AIProvider, @unchecked Sendable {
    public let providerID = "gmicloud"
    public let supportedCapabilities: Set<ModelCapability> = [.language]

    private let config: OpenAICompatibleModelConfiguration

    public init(configuration settings: GMICloudProviderSettings) throws {
        let headers = try gmiCloudHeaders(settings: settings)
        let baseURL = withoutTrailingSlash(settings.baseURL ?? "https://api.gmi-serving.com/v1")
        var configured = OpenAICompatibleModelConfiguration(http: AIProviderHTTPClient(
            providerID: "gmicloud.chat", headers: headers, transport: settings.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }), baseURL: baseURL)
        configured.includeUsage = true
        configured.supportsStructuredOutputs = settings.supportsStructuredOutputs
        configured.transformRequestBody = settings.transformRequestBody
        configured.usesGenericOpenAICompatibleProviderOptions = false
        configured.allowsEmptyTextResponse = false
        configured.chatErrorHandler = gmiCloudHTTPStatusError
        config = configured
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleChatModel(modelID: modelID, config: config)
    }

    public func callAsFunction(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func chatModel(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
    }

    public func chat(_ modelID: String) throws -> any LanguageModel {
        try languageModel(modelID)
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
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }
}

private func gmiCloudHeaders(settings: GMICloudProviderSettings) throws -> [String: String] {
    let apiKey = settings.apiKey ?? settings.environmentValue(["GMI_CLOUD_APIKEY"])
    guard let apiKey else {
        throw AIError.missingAPIKey(provider: "gmicloud", environmentVariables: ["GMI_CLOUD_APIKEY"])
    }

    var headers = settings.headers
    if !headers.keys.contains(where: { $0.caseInsensitiveCompare("authorization") == .orderedSame }) {
        headers["Authorization"] = "Bearer \(apiKey)"
    }
    return withUserAgentSuffix(headers, "ai-sdk-gmicloud/\(gmiCloudProviderVersion)")
}

/// GMI's edge stores the backend engine diagnostic as JSON inside
/// `error.details`; prefer that message over the generic outer banner.
func gmiCloudErrorMessage(from data: Data) -> String? {
    guard let response = try? decodeJSONBody(data),
          let outerMessage = response["error"]?["message"]?.stringValue else {
        return nil
    }
    guard let details = response["error"]?["details"]?.stringValue,
          !details.isEmpty,
          let nested = try? secureJSONParse(details),
          let nestedMessage = nested["error"]?["message"]?.stringValue,
          !nestedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return outerMessage
    }
    return nestedMessage
}
public func gmiCloudHTTPStatusError(_ response: AIHTTPResponse) -> AIError {
    let body = gmiCloudErrorMessage(from: response.body) ?? response.bodyText
    if response.headers.isEmpty { return .apiCall(provider: "gmicloud.chat", statusCode: response.statusCode, body: body) }
    return .apiCall(provider: "gmicloud.chat", statusCode: response.statusCode, body: body, headers: response.headers)
}

public extension AIProviders {
    static func gmiCloud(configuration: GMICloudProviderSettings) throws -> GMICloudProvider { try GMICloudProvider(configuration: configuration) }
}
