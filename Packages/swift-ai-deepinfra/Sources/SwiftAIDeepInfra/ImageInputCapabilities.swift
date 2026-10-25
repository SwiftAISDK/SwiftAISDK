import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension DeepInfraImageModel {
    var supportsFileInputs: Bool? {
        if ["stabilityai/sd3.5", "black-forest-labs/FLUX-1.1-pro", "black-forest-labs/FLUX-1-schnell", "black-forest-labs/FLUX-1-dev", "black-forest-labs/FLUX-pro", "black-forest-labs/FLUX.1-Kontext-dev", "black-forest-labs/FLUX.1-Kontext-pro", "Qwen/Qwen-Image-Edit", "stabilityai/sd3.5-medium", "stabilityai/sdxl-turbo"].contains(modelID) { return true }
        return nil
    }

    var supportsMaskInputs: Bool? {
        supportsFileInputs
    }
}