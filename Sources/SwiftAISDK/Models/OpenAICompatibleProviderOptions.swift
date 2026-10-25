import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI

func isOpenAIBackedProvider(_ providerID: String, config: ModelHTTPConfig) -> Bool {
    openAIBackedProviderRoot(providerID, config: config) != nil
}

func openAIBackedProviderRoot(_ providerID: String, config: ModelHTTPConfig) -> String? {
    config.openAIBackedProviderRoot ?? openAIBackedProviderRoot(providerID)
}
func isOpenAIBackedProvider(_ providerID: String) -> Bool { SwiftAIOpenAICompatible.isOpenAIBackedProvider(providerID) }
func openAIBackedProviderRoot(_ providerID: String) -> String? { SwiftAIOpenAICompatible.openAIBackedProviderRoot(providerID) }
