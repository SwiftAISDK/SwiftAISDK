import Foundation
import SwiftAIProvider
import SwiftAITransport

/// Sends one request to the Liquid Decisions API and retains the raw result.
public final class DecisionLiquidModel: AIDecisionModelV4, Sendable {
    public let providerID = "liquid.decision"
    public let modelID: LiquidDecisionModelID
    public let supportedQuestionTypes: [AIDecisionQuestionType] = [.choice, .score, .boolean, .box]
    private let configuration: LiquidProviderSettings

    init(modelID: LiquidDecisionModelID, configuration: LiquidProviderSettings) {
        self.modelID = modelID
        self.configuration = configuration
    }

    public func doDecide(_ options: AIDecisionModelV4CallOptions) async throws -> AIDecisionModelV4Result {
        let body = try liquidDecisionBody(modelID: modelID, options: options)
        try options.abortSignal?.throwIfAborted()
        try Task.checkCancellation()
        let key = try await configuration.resolveAPIKey()
        try options.abortSignal?.throwIfAborted()
        try Task.checkCancellation()
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://api.liquid.ai")
        let providerHeaders = combineHeaders(["authorization": "Bearer \(key)"], normalizeHeaders(configuration.headers))
        let agentHeaders = withUserAgentSuffix(providerHeaders, "ai-sdk-liquid/\(liquidProviderVersion)")
        let headers = prepareHeaders(
            combineHeaders(agentHeaders, normalizeHeaders(options.headers)),
            defaultHeaders: ["content-type": "application/json"]
        )
        let request = AIHTTPRequest(
            method: "POST",
            url: try requireURL("\(baseURL)/decisions/v1/systemone"),
            headers: headers,
            body: try encodeJSONBody(body),
            abortSignal: options.abortSignal
        )
        let response = try await configuration.transport.send(request)
        try options.abortSignal?.throwIfAborted()
        try Task.checkCancellation()

        func apiError(message: String?, retryable: Bool? = nil) -> AIError {
            var error = AIAPICallError(
                provider: providerID,
                url: request.url.absoluteString,
                requestBody: body,
                statusCode: response.statusCode,
                responseHeaders: response.headers,
                responseBody: response.bodyText,
                isRetryable: retryable
            )
            error.message = message
            return .apiCall(error)
        }

        guard (200..<300).contains(response.statusCode) else {
            let error = (try? response.jsonValue())?["error"]
            let message = error?["message"]?.stringValue
            let code = error?["code"]?.stringValue
            throw apiError(message: message.map { message in code.map { "\(message) (\($0))" } ?? message })
        }
        let raw: JSONValue
        let result: LiquidDecisionResponse
        do {
            raw = try response.jsonValue()
            result = try JSONDecoder().decode(LiquidDecisionResponse.self, from: response.body)
        } catch {
            throw apiError(message: "Invalid Liquid decision response.", retryable: false)
        }
        guard Set(result.answers.keys) == Set(options.questions.keys) else {
            throw AIError.invalidResponse(provider: providerID, message: "Liquid must return exactly one answer for every question.")
        }

        var warnings: [AIWarning] = []
        if options.maxOutputTokens != nil {
            warnings.append(.init(type: "unsupported", feature: "maxOutputTokens"))
        }
        if options.reasoning != nil {
            warnings.append(.init(type: "unsupported", feature: "reasoning"))
        }
        if let providerOptions = options.providerOptions["liquid"]?.objectValue {
            warnings += providerOptions.keys.sorted().map {
                .init(type: "unsupported", feature: "providerOptions.liquid.\($0)")
            }
        }
        return .init(
            answers: result.answers.mapValues(\.value),
            usage: result.usage?.tokens,
            warnings: warnings,
            providerMetadata: ["liquid": result.metadata],
            response: .init(modelID: result.model ?? modelID, headers: response.headers, body: raw)
        )
    }
}
