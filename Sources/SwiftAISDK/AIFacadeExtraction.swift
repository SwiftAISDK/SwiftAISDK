import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI

public extension AI {
    /// Resolves an extraction model through the configured default provider.
    static func experimentalExtract(
        model: String,
        state: AIDecisionState,
        fields: [String: AIExtractionField],
        referenceDate: String? = nil,
        maxOutputTokens: Int? = nil,
        reasoning: String? = nil,
        maxRetries: Int? = nil,
        abortSignal: AIAbortSignal? = nil,
        download: AIDownloadFunction? = nil,
        headers: [String: String] = [:],
        providerOptions: [String: JSONValue] = [:]
    ) async throws -> AIExtractionResult {
        let resolved = try AIDefaultProvider.resolveExtractionModel(model)
        return try await SwiftAI.AI.experimentalExtract(model: resolved, state: state, fields: fields,
            referenceDate: referenceDate, maxOutputTokens: maxOutputTokens, reasoning: reasoning,
            maxRetries: maxRetries, abortSignal: abortSignal, download: download,
            headers: headers, providerOptions: providerOptions)
    }
}
