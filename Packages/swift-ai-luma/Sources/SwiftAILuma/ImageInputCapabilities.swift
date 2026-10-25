import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension LumaImageModel {
    var supportsFileInputs: Bool? {
        if ["photon-1", "photon-flash-1"].contains(modelID) { return true }
        return nil
    }

    var supportsMaskInputs: Bool? {
        return supportsFileInputs == nil ? nil : false
    }
}
