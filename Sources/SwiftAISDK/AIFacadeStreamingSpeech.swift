import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAI


extension AI {

    public static func experimentalStreamSpeech(model modelID: String, provider: (any AIProvider)? = nil,
                                                request: StreamingSpeechRequest,
                                                onError: @escaping @Sendable (any Error) async throws -> Void = { error in FileHandle.standardError.write(Data("\(error)\n".utf8)) }) throws -> StreamingSpeechResult {
        try experimentalStreamSpeech(model: resolveSpeechModel(modelID, provider: provider), request: request, onError: onError)
    }
}
