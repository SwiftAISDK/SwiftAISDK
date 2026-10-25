import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension FireworksImageModel {
    var supportsFileInputs: Bool? {
        if ["accounts/fireworks/models/flux-kontext-pro", "accounts/fireworks/models/flux-kontext-max"].contains(modelID) { return true }
        if ["accounts/fireworks/models/flux-1-dev-fp8", "accounts/fireworks/models/flux-1-schnell-fp8", "accounts/fireworks/models/playground-v2-5-1024px-aesthetic", "accounts/fireworks/models/japanese-stable-diffusion-xl", "accounts/fireworks/models/playground-v2-1024px-aesthetic", "accounts/fireworks/models/SSD-1B", "accounts/fireworks/models/stable-diffusion-xl-1024-v1-0"].contains(modelID) { return false }
        return nil
    }

    var supportsMaskInputs: Bool? {
        return supportsFileInputs == nil ? nil : false
    }
}