import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension ReplicateImageModel {
    var supportsFileInputs: Bool? {
        if ["black-forest-labs/flux-2-pro", "black-forest-labs/flux-2-dev", "black-forest-labs/flux-fill-pro", "black-forest-labs/flux-fill-dev"].contains(modelID) { return true }
        return nil
    }

    var supportsMaskInputs: Bool? {
        if ["black-forest-labs/flux-fill-pro", "black-forest-labs/flux-fill-dev"].contains(modelID) { return true }
        return supportsFileInputs == nil ? nil : false
    }
}
