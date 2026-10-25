import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGoogle

public extension GoogleGenerativeAIProvider {
    convenience init(settings: ProviderSettings = ProviderSettings()) throws {
        let providerID = settings.name ?? "google.generative-ai"
        let headers = try OpenAICompatibleProvider.buildHeaders(providerID: providerID,
            authorization: .apiKeyHeader(name: "x-goog-api-key", environmentVariables: ["GOOGLE_GENERATIVE_AI_API_KEY", "GOOGLE_API_KEY", "GEMINI_API_KEY"]), settings: settings)
        let baseURL = withoutTrailingSlash(settings.baseURL ?? "https://generativelanguage.googleapis.com/v1beta")
        var configuration = GoogleModelConfiguration(
            http: AIProviderHTTPClient(providerID: providerID, headers: headers, transport: settings.transport,
                url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: settings.queryParams) }),
            baseURL: baseURL, transformRequestBody: settings.transformRequestBody,
            batchResultMaxLineBytes: settings.batchResultDownloads?.maxLineBytes)
        configuration.errorHandler = { compatibilityAPICallError(provider: $0, response: $1) }
        self.init(modelConfiguration: configuration)
    }
}
