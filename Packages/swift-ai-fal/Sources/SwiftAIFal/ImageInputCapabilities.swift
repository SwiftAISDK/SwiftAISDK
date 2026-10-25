import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



public extension FalImageModel {
    var supportsFileInputs: Bool? {
        if ["fal-ai/flux-2/edit", "fal-ai/flux-pro/kontext", "fal-ai/flux-pro/kontext/max", "fal-ai/flux-general/image-to-image", "fal-ai/flux-general/inpainting", "fal-ai/flux-lora/image-to-image", "fal-ai/flux-lora/inpainting", "fal-ai/flux/dev/image-to-image", "fal-ai/flux/krea/image-to-image", "fal-ai/recraft/v3/image-to-image"].contains(modelID) { return true }
        if ["bria/text-to-image/3.2", "fal-ai/bria/text-to-image/base", "fal-ai/bria/text-to-image/fast", "fal-ai/bria/text-to-image/hd", "fal-ai/bytedance/dreamina/v3.1/text-to-image", "fal-ai/flux-kontext-lora/text-to-image", "fal-ai/recraft/v3/text-to-image", "fal-ai/wan/v2.2-5b/text-to-image", "fal-ai/wan/v2.2-a14b/text-to-image"].contains(modelID) { return false }
        return nil
    }

    var supportsMaskInputs: Bool? {
        if ["fal-ai/flux-general/inpainting", "fal-ai/flux-lora/inpainting"].contains(modelID) { return true }
        return supportsFileInputs == nil ? nil : false
    }
}
