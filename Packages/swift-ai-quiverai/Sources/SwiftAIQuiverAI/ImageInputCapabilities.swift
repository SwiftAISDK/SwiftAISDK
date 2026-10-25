import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension QuiverAIImageModel {
    var supportsFileInputs: Bool? {
        if ["arrow-1", "arrow-1.1", "arrow-1.1-max", "arrow-2", "arrow-2-telos"].contains(modelID) { return true }
        return nil
    }

    var supportsMaskInputs: Bool? {
        return supportsFileInputs == nil ? nil : false
    }
}