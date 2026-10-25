import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI
import SwiftAIOpenAICompatible


public extension XAIImageModel {
    var supportsFileInputs: Bool? {
        if ["grok-imagine-image", "grok-imagine-image-pro", "grok-imagine-image-2.0"].contains(modelID) { return true }
        return nil
    }

    var supportsMaskInputs: Bool? {
        return supportsFileInputs == nil ? nil : false
    }
}
