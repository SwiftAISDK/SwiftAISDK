import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension ProdiaImageModel {
    var supportsFileInputs: Bool? { false }
    var supportsMaskInputs: Bool? { false }
}