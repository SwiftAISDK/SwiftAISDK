import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIElevenLabs

extension ElevenLabsTranscriptionModel {
    convenience init(modelID: String, config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ElevenLabsSpeechModel {
    convenience init(modelID: String, config: ModelHTTPConfig, webSocketTransport: any AIDuplexWebSocketTransport = URLSessionDuplexWebSocketTransport.shared) {
        self.init(modelID: modelID, config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL), webSocketTransport: webSocketTransport)
    }
}

extension ElevenLabsMusicModel {
    convenience init(modelID: String = "music_v1", config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ElevenLabsSoundEffectsModel {
    convenience init(modelID: String = "eleven_text_to_sound_v2", config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ElevenLabsVoiceChangerModel {
    convenience init(modelID: String = "eleven_multilingual_sts_v2", config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ElevenLabsVoiceIsolatorModel {
    convenience init(modelID: String = "audio-isolation", config: ModelHTTPConfig) {
        self.init(modelID: modelID, config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}

extension ElevenLabsDubbingClient {
    convenience init(config: ModelHTTPConfig) {
        self.init(config: ElevenLabsModelConfiguration(http: config.httpClient, baseURL: config.baseURL))
    }
}
