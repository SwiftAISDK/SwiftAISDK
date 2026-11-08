import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

private actor WeeklyOpenAIKeys {
    var count = 0
    func next() -> String { count += 1; return "token-\(count)" }
}

@Suite struct Weekly20261101OpenAICredentialsTests {
    @Test func apiKeyIsResolvedForEveryRequestAndOverrideWins() async throws {
        let keys = WeeklyOpenAIKeys()
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output_text":"done"}"#))
        let provider = try OpenAIProvider(configuration: .init(transport: transport, apiKeyProvider: { await keys.next() }))
        let model = provider.responses("gpt-5.5")
        for _ in 0..<2 { _ = try await model.generate(.init(messages: [.user("Hi")])) }
        _ = try await model.generate(.init(messages: [.user("Hi")], headers: ["authorization": "Bearer request"]))
        let requests = await transport.requests()
        #expect(requests.map { $0.headers.first { $0.key.lowercased() == "authorization" }?.value } == ["Bearer token-1", "Bearer token-2", "Bearer request"])
        #expect(await keys.count == 2)
    }

    @Test func providerAuthorizationOverrideSkipsSupplier() async throws {
        let keys = WeeklyOpenAIKeys()
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"r","status":"completed","output_text":"done"}"#))
        let provider = try OpenAIProvider(configuration: .init(headers: ["AUTHORIZATION": "Bearer custom"], transport: transport, apiKeyProvider: { await keys.next() }))
        _ = try await provider.responses("gpt-5.5").generate(.init(messages: [.user("Hi")]))
        #expect(await keys.count == 0)
        #expect(await transport.requests().first?.headers["authorization"] == "Bearer custom")
    }

    @Test func liveConfigurationRefreshesAtEachConnection() async throws {
        let keys = WeeklyOpenAIKeys()
        let provider = try OpenAIProvider(configuration: .init(apiKeyProvider: { await keys.next() }))
        let model = try provider.experimentalRealtime("gpt-live-1")
        let first = try await model.getResolvedServerWebSocketConfig()
        let second = try await model.getResolvedServerWebSocketConfig()
        #expect(first.headers.first { $0.key.lowercased() == "authorization" }?.value == "Bearer token-1")
        #expect(second.headers.first { $0.key.lowercased() == "authorization" }?.value == "Bearer token-2")
    }

    @Test(arguments: [("gpt-live-transcribe", true), ("gpt-live-transcribe-2026-01-01", true), ("gpt-transcribe", false), ("gpt-transcribe-2026-01-01", false)])
    func streamingTranscriptionUsesLanguagesAndWarnsForUnsupportedDelay(_ modelID: String, _ supportsDelay: Bool) async throws {
        let transport = RealtimeTestWebSocketTransport()
        let provider = try OpenAIProvider(configuration: .init(apiKey: "key", webSocketTransport: transport))
        let audio = AIStreamingAudioInput.makeStream()
        audio.writer.send(Data([1, 2])); audio.writer.finish()
        let result = try await provider.streamingTranscriptionModel(modelID).stream(.init(audio: audio.input, inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 24000), providerOptions: ["openai": ["language": "en", "streaming": ["delay": "low"]]]))
        let collector = Task { () throws -> [StreamingTranscriptionPart] in var parts: [StreamingTranscriptionPart] = []; for try await part in result.stream { parts.append(part) }; return parts }
        transport.connection.open()
        #expect(await realtimeWait { !transport.connection.sentMessages().isEmpty })
        let update = try #require(transport.connection.sentJSONMessages().first)
        #expect(update["session"]?["audio"]?["input"]?["transcription"]?["languages"] == ["en"])
        #expect(update["session"]?["audio"]?["input"]?["transcription"]?["delay"] == (supportsDelay ? .string("low") : nil))
        transport.connection.sendJSON(["type": "conversation.item.input_audio_transcription.completed", "item_id": "one", "transcript": "Hello"])
        let parts = try await collector.value
        #expect(parts.contains(.transcriptFinal(id: "one", text: "Hello")))
        #expect(parts.contains { if case let .streamStart(warnings) = $0 { return warnings.contains { $0.feature == "providerOptions.openai.streaming.delay" } == !supportsDelay }; return false })
    }
}
