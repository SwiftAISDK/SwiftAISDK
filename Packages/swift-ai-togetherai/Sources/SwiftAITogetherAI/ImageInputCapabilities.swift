import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension TogetherAIImageModel {
    var supportsFileInputs: Bool? {
        if ["black-forest-labs/FLUX.1-kontext-pro", "black-forest-labs/FLUX.1-kontext-max", "black-forest-labs/FLUX.1-kontext-dev", "black-forest-labs/FLUX.1-canny", "black-forest-labs/FLUX.1-depth", "black-forest-labs/FLUX.1-redux", "black-forest-labs/FLUX.2-pro", "black-forest-labs/FLUX.2-flex"].contains(modelID) { return true }
        if ["stabilityai/stable-diffusion-xl-base-1.0", "black-forest-labs/FLUX.1-dev", "black-forest-labs/FLUX.1-dev-lora", "black-forest-labs/FLUX.1-schnell", "black-forest-labs/FLUX.1.1-pro", "black-forest-labs/FLUX.1-pro", "black-forest-labs/FLUX.1-schnell-Free", "black-forest-labs/FLUX.2-dev", "google/gemini-3-pro-image"].contains(modelID) { return false }
        return nil
    }

    var supportsMaskInputs: Bool? {
        return supportsFileInputs == nil ? nil : false
    }
}
