import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible


func xaiChatUsage(from raw: JSONValue) -> TokenUsage? {
    guard let usage = raw["usage"] else { return nil }
    let inputTokens = usage["prompt_tokens"]?.intValue ?? usage["input_tokens"]?.intValue ?? 0
    let outputTextTokens = usage["completion_tokens"]?.intValue ?? usage["output_tokens"]?.intValue ?? 0
    let cacheReadTokens = usage["prompt_tokens_details"]?["cached_tokens"]?.intValue ?? 0
    let reasoningTokens = usage["completion_tokens_details"]?["reasoning_tokens"]?.intValue ?? 0
    let promptTokensIncludesCached = cacheReadTokens <= inputTokens
    let totalInputTokens = promptTokensIncludesCached ? inputTokens : inputTokens + cacheReadTokens
    let inputNoCacheTokens = promptTokensIncludesCached ? inputTokens - cacheReadTokens : inputTokens
    let outputTokens = outputTextTokens + reasoningTokens
    return TokenUsage(
        inputTokens: totalInputTokens,
        outputTokens: outputTokens,
        totalTokens: usage["total_tokens"]?.intValue ?? totalInputTokens + outputTokens,
        inputTokensNoCache: inputNoCacheTokens,
        inputTokensCacheRead: cacheReadTokens,
        outputTextTokens: outputTextTokens,
        outputReasoningTokens: reasoningTokens,
        rawValue: usage
    )
}