import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIGoogle
public extension GoogleVertexImageModel {
    var supportsFileInputs: Bool? {
        if ["gemini-2.5-flash-image", "gemini-3-pro-image-preview", "gemini-3.1-flash-image-preview", "gemini-nano-banana-2.1"].contains(modelID) { return true }
        return nil
    }

    var supportsMaskInputs: Bool? {
        return supportsFileInputs == nil ? nil : false
    }
}
