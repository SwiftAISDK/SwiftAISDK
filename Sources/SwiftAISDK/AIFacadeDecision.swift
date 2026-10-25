import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI


extension AI {

    /// Resolves a decision model ID through the configured default provider.
    public static func experimentalDecide(
        model: String,
        state: AIDecisionState,
        questions: [String: AIDecisionQuestion],
        maxOutputTokens: Int? = nil,
        reasoning: String? = nil,
        maxRetries: Int? = nil,
        abortSignal: AIAbortSignal? = nil,
        headers: [String: String] = [:],
        providerOptions: [String: JSONValue] = [:],
        telemetry: Telemetry.Options? = nil,
        runtimeContext: [String: JSONValue] = [:],
        onStart: AICallback<AIDecisionStartEvent>? = nil,
        onEnd: AICallback<AIDecisionEndEvent>? = nil
    ) async throws -> AIDecisionResult {
        try await experimentalDecide(model: .modelID(model), state: state, questions: questions, maxOutputTokens: maxOutputTokens, reasoning: reasoning, maxRetries: maxRetries, abortSignal: abortSignal, headers: headers, providerOptions: providerOptions, telemetry: telemetry, runtimeContext: runtimeContext, onStart: onStart, onEnd: onEnd)
    }
}
