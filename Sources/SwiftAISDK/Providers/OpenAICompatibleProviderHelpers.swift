import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIBaseten
import SwiftAIDeepInfra

func basetenDefaultChatModelID(config: ModelHTTPConfig) -> String {
    basetenDefaultChatModelID(modelURL: config.modelURL)
}

func basetenChatConfig(from config: ModelHTTPConfig) throws -> ModelHTTPConfig {
    if let modelURL = try basetenChatBaseURL(modelURL: config.modelURL) {
        return config.withBaseURL(modelURL).withProviderID("baseten.chat")
    }
    return config.withProviderID("baseten.chat")
}
