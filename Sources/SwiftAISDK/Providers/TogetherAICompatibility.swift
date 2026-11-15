import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAITogetherAI

extension TogetherAIImageModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: TogetherAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings))
    }
}

extension TogetherAIRerankingModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: TogetherAIModelConfiguration(http: config.httpClient, baseURL: config.baseURL ,supportsStructuredOutputs: config.supportsStructuredOutputs, supportsMultiPartToolContent: config.supportsMultiPartToolContent, maxEmbeddingsPerCall: config.maxEmbeddingsPerCall, transformRequestBody: config.transformRequestBody, transformRequestBodyWithWarnings: config.transformRequestBodyWithWarnings))
    }
}

// Mirrors upstream `jsonSchemaModelIDs` in togetherai-model-catalog.ts and the
// native `TogetherAIProvider` set; other IDs use the JSON-object fallback.
let togetherAIJSONSchemaModelIDs: Set<String> = [
    "deepseek-ai/DeepSeek-V4-Flash-0731",
    "deepseek-ai/DeepSeek-V4.1-Flash",
    "deepseek-ai/DeepSeek-V4.1-Flash-1017",
    "openai/gpt-oss-120b",
    "zai-org/GLM-5.2",
    "zai-org/GLM-5.3-Flash",
    "moonshotai/Kimi-K3",
    "MiniMaxAI/MiniMax-M3.1-Flash"
]
