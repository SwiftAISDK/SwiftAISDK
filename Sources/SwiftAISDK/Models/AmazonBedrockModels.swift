import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI


public enum AmazonBedrockChatModelFamily: String, Sendable {
    case anthropic
}

public struct AmazonBedrockChatModelSettings: Sendable {
    public var modelFamily: AmazonBedrockChatModelFamily?

    public init(modelFamily: AmazonBedrockChatModelFamily? = nil) {
        self.modelFamily = modelFamily
    }
}