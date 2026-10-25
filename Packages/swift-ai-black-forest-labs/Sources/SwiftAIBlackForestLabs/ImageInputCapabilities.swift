import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

// Model capabilities from the published upstream packages. Unknown IDs follow each provider's routing policy.

public extension BlackForestLabsImageModel {
    var supportsFileInputs: Bool? {
        if blackForestLabsImageAPI(for: modelID) != .legacy { return true }
        if ["flux-kontext-pro", "flux-kontext-max", "flux-pro-1.0-fill", "flux-3-image"].contains(modelID) { return true }
        if ["flux-pro-1.1-ultra", "flux-pro-1.1"].contains(modelID) { return false }
        return nil
    }

    var supportsMaskInputs: Bool? {
        if blackForestLabsImageAPI(for: modelID) != .legacy { return false }
        if ["flux-pro-1.0-fill"].contains(modelID) { return true }
        return supportsFileInputs == nil ? nil : false
    }
}
