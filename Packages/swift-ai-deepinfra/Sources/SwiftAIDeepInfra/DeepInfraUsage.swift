import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public func deepInfraChatUsage(from raw: JSONValue) -> TokenUsage? {
    guard let usage = raw["usage"] else { return tokenUsage(from: raw) }
    let inputTokens = usage["prompt_tokens"]?.intValue ?? usage["input_tokens"]?.intValue ?? 0
    let completionTokens = usage["completion_tokens"]?.intValue ?? 0
    let reasoningTokens = usage["completion_tokens_details"]?["reasoning_tokens"]?.intValue ?? 0
    guard reasoningTokens > completionTokens else {
        return tokenUsage(from: raw)
    }

    let correctedCompletionTokens = completionTokens + reasoningTokens
    let cacheReadTokens = usage["prompt_tokens_details"]?["cached_tokens"]?.intValue ?? 0
    var fixedUsage = usage.objectValue ?? [:]
    fixedUsage["completion_tokens"] = .number(Double(correctedCompletionTokens))
    let totalTokens = usage["total_tokens"]?.intValue.map { $0 + reasoningTokens } ?? inputTokens + correctedCompletionTokens
    fixedUsage["total_tokens"] = .number(Double(totalTokens))
    return TokenUsage(
        inputTokens: inputTokens,
        outputTokens: correctedCompletionTokens,
        totalTokens: totalTokens,
        inputTokensNoCache: inputTokens - cacheReadTokens,
        inputTokensCacheRead: cacheReadTokens,
        outputTextTokens: correctedCompletionTokens - reasoningTokens,
        outputReasoningTokens: reasoningTokens,
        rawValue: .object(fixedUsage)
    )
}