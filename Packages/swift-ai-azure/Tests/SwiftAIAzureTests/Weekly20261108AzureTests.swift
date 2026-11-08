import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAzure

@Suite struct Weekly20261108AzureTests {
    @Test func azureOpenAIOptionsMergeWithAzurePrecedenceAcrossSurfaces() async throws {
        let transport = RecordingTransport(responses: [jsonResponse(#"{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}]}"#), AIHTTPResponse(statusCode: 200, body: Data([1])), jsonResponse(#"{"text":"hi"}"#), jsonResponse(#"{"data":[{"b64_json":"aGk="}]}"#)])
        let provider = try AzureOpenAIProvider(resourceName: "test", configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.chatModel("deployment").generate(.init(messages: [.user("Hi")], providerOptions: ["openai": ["user": "old", "logitBias": ["2": -100]], "azure": ["user": "new"]]))
        var request = try #require(await transport.requests().last)
        let chat = try decodeJSONBody(#require(request.body))
        #expect(chat["user"] == "new"); #expect(chat["logit_bias"]?["2"] == -100)
        _ = try await provider.speechModel("tts-1").speak(.init(text: "Hi", providerOptions: ["openai": ["speed": 2], "azure": ["speed": 1.5, "instructions": "Calm"]]))
        request = try #require(await transport.requests().last)
        let speech = try decodeJSONBody(#require(request.body))
        #expect(speech["speed"] == 1.5); #expect(speech["instructions"] == "Calm")
        _ = try await provider.transcriptionModel("whisper-1").transcribe(.init(audio: Data([1]), providerOptions: ["openai": ["language": "de", "prompt": "Names"], "azure": ["language": "en"]]))
        request = try #require(await transport.requests().last)
        let transcript = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(transcript.contains("\r\n\r\nen\r\n")); #expect(transcript.contains("Names"))
        _ = try await provider.imageModel("gpt-image-1").generateImage(.init(prompt: "Hi", providerOptions: ["openai": ["quality": "low", "background": "opaque"], "azure": ["quality": "high"]]))
        let image = try decodeJSONBody(#require(await transport.requests().last?.body))
        #expect(image["quality"] == "high"); #expect(image["background"] == "opaque")
    }

    @Test func azureSpeechSharedTimingsAndWordResultsMatchPublishedBehavior() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"combinedPhrases":[{"text":"Um"}],"phrases":[{"text":"Um","offsetMilliseconds":120,"durationMilliseconds":220,"words":[{"text":"Um","offsetMilliseconds":120,"durationMilliseconds":220}]}]}"#))
        let provider = try AzureOpenAIProvider(resourceName: "test", configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.transcriptionModel("mai-transcribe-2").transcribe(.init(audio: Data([1]), timestampGranularities: [.word, .segment]))
        let body = String(decoding: try #require(await transport.requests().first?.body), as: UTF8.self)
        #expect(body.contains("\"timestamps\":\"word\""))
        #expect(result.words == [.init(text: "Um", startSecond: 0.12, endSecond: 0.34)])
        #expect(result.warnings.isEmpty)
        let overridden = try await provider.transcriptionModel("mai-transcribe-2").transcribe(.init(audio: Data([1]), providerOptions: ["azure": ["timestamps": "none"]], timestampGranularities: [.word]))
        #expect(overridden.warnings.count == 1)
        let unsupported = try await provider.transcriptionModel("mai-transcribe-1.5").transcribe(.init(audio: Data([1]), timestampGranularities: [.word]))
        #expect(unsupported.warnings.count == 1)
    }

    @Test func azureOptionsReachOpenAIStreamingTranscription() async throws {
        let socket = RealtimeTestWebSocketTransport()
        let provider = try AzureOpenAIProvider(resourceName: "test", configuration: .init(apiKey: "key"), audioSettings: .init(webSocketTransport: socket))
        let audio = AIStreamingAudioInput.makeStream()
        let result = try await provider.streamingTranscriptionModel("gpt-live-transcribe").stream(.init(audio: audio.input, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 24000), providerOptions: ["openai": ["language": "de"], "azure": ["language": "en"]]))
        let collector = Task { try await realtimeCollect(result.stream) }
        socket.connection.open()
        #expect(await realtimeWait { socket.connection.sentMessages().count == 1 })
        let update = try #require(socket.connection.sentJSONMessages().first)
        #expect(update["session"]?["audio"]?["input"]?["transcription"]?["languages"] == ["en"])
        #expect(socket.requests().first?.url.absoluteString.contains("intent=transcription") == true)
        audio.writer.finish()
        socket.connection.sendJSON(["type": "conversation.item.input_audio_transcription.completed", "item_id": "item", "transcript": "Hi"])
        _ = try await collector.value
    }

    @Test func azureAddsSharedClientToolFactories() {
        #expect(AzureOpenAITools.customTool()["id"] == "openai.custom")
        #expect(AzureOpenAITools.applyPatch()["id"] == "openai.apply_patch")
        #expect(AzureOpenAITools.shell(environment: ["type": "containerAuto"])["id"] == "openai.shell")
    }
}
