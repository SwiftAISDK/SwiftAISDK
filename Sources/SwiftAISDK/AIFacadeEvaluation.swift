import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI


extension AI {

    /// Source-compatible model-ID entry point retained from SwiftAISDK 1.9.0.
    public static func experimentalEvaluate(
        model: String,
        state: JSONValue,
        questions: [String: AIEvaluationQuestion],
        maxRetries: Int? = nil,
        abortSignal: AIAbortSignal? = nil,
        headers: [String: String] = [:],
        providerOptions: [String: JSONValue] = [:]
    ) async throws -> AIEvaluationResult {
        try await experimentalEvaluate(
            model: model,
            state: state,
            questions: questions,
            maxRetries: maxRetries,
            abortSignal: abortSignal,
            headers: headers,
            providerOptions: providerOptions,
            telemetry: nil,
            runtimeContext: [:],
            onStart: nil,
            onEnd: nil
        )
    }

    /// Resolves an evaluation model ID through the configured default provider.
    public static func experimentalEvaluate(
        model: String,
        state: JSONValue,
        questions: [String: AIEvaluationQuestion],
        maxRetries: Int? = nil,
        abortSignal: AIAbortSignal? = nil,
        headers: [String: String] = [:],
        providerOptions: [String: JSONValue] = [:],
        telemetry: Telemetry.Options? = nil,
        runtimeContext: [String: JSONValue] = [:],
        onStart: AICallback<AIEvaluationStartEvent>? = nil,
        onEnd: AICallback<AIEvaluationEndEvent>? = nil
    ) async throws -> AIEvaluationResult {
        try await experimentalEvaluate(
            model: .modelID(model),
            state: state,
            questions: questions,
            maxRetries: maxRetries,
            abortSignal: abortSignal,
            headers: headers,
            providerOptions: providerOptions,
            telemetry: telemetry,
            runtimeContext: runtimeContext,
            onStart: onStart,
            onEnd: onEnd
        )
    }
}



extension AI {

    public static func experimentalEvaluate(
        model: String,
        stateParts: [AIDecisionStatePart],
        questions: [String: AIEvaluationQuestion],
        maxRetries: Int? = nil,
        abortSignal: AIAbortSignal? = nil,
        headers: [String: String] = [:],
        providerOptions: [String: JSONValue] = [:],
        telemetry: Telemetry.Options? = nil,
        runtimeContext: [String: JSONValue] = [:],
        onStart: AICallback<AIEvaluationStartEvent>? = nil,
        onEnd: AICallback<AIEvaluationEndEvent>? = nil
    ) async throws -> AIEvaluationResult {
        try await experimentalEvaluate(model: .modelID(model), stateParts: stateParts, questions: questions, maxRetries: maxRetries, abortSignal: abortSignal, headers: headers, providerOptions: providerOptions, telemetry: telemetry, runtimeContext: runtimeContext, onStart: onStart, onEnd: onEnd)
    }
}
