import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible
import SwiftAIDeepSeek
import SwiftAIAzure

extension ProviderSettings {
    var azureSettings: AzureOpenAIProviderSettings {
        .init(apiKey: apiKey, baseURL: baseURL, headers: headers, queryParams: queryParams, transport: transport,
              includeUsage: includeUsage, supportsStructuredOutputs: supportsStructuredOutputs,
              maxEmbeddingsPerCall: maxEmbeddingsPerCall, transformRequestBody: transformRequestBody)
    }
}

public extension AzureOpenAIProvider {
    convenience init(resourceName: String? = nil, apiVersion: String = "v1", useDeploymentBasedURLs: Bool = false,
                     tokenProvider: AzureOpenAITokenProvider? = nil, settings: ProviderSettings = ProviderSettings()) throws {
        try self.init(resourceName: resourceName, apiVersion: apiVersion, useDeploymentBasedURLs: useDeploymentBasedURLs,
                      tokenProvider: tokenProvider, configuration: settings.azureSettings)
    }
    convenience init(resourceName: String? = nil, apiVersion: String = "v1", useDeploymentBasedURLs: Bool = false,
                     tokenProvider: AzureOpenAITokenProvider? = nil, settings: ProviderSettings = ProviderSettings(),
                     audioSettings: AzureOpenAIAudioSettings) throws {
        try self.init(resourceName: resourceName, apiVersion: apiVersion, useDeploymentBasedURLs: useDeploymentBasedURLs,
                      tokenProvider: tokenProvider, configuration: settings.azureSettings, audioSettings: audioSettings)
    }
}
