import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIXAI

private actor WeeklyCredentialSequence {
    private(set) var count = 0
    func next() -> String { count += 1; return "rotating-\(count)" }
}
private actor WeeklyCredentialProbe: AITransport {
    private(set) var requests: [AIHTTPRequest] = []
    struct Sent: Error {}
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        requests.append(request)
        throw Sent()
    }
}

@Suite("Weekly20261101 xai credentials")
struct Weekly20261101CredentialsTests {
    @Test func resolvesFreshCredentialOnlyWhenRequestIsSent() async throws {
        let sequence = WeeklyCredentialSequence()
        let transport = WeeklyCredentialProbe()
        let provider = try XAIProvider(configuration: XAIProviderSettings(apiKeyProvider: { await sequence.next() }, transport: transport))
        let model = try provider.languageModel("grok-4.3")
        #expect(await sequence.count == 0)
        for _ in 0..<2 { _ = try? await model.generate(LanguageModelRequest(messages: [.user("Hello")])) }
        _ = try? await provider.chat("grok-4.6").generate(.init(messages: [.user("Hello")]))
        _ = try? await provider.files().getFileMetadata(.init(file: ["xai": "file-1"]))
        _ = try? await provider.experimentalBatch().getBatchStatus(.init(batchID: "batch-1"))
        _ = try? await provider.speech().speak(.init(text: "Hello"))
        _ = try? await provider.transcription().transcribe(.init(audio: Data([1]), mimeType: "audio/wav"))
        _ = try? await provider.imageModel("grok-imagine-image").generateImage(.init(prompt: "cat"))
        _ = try? await provider.videoModel("grok-imagine-video").generateVideo(.init(prompt: "cat"))
        _ = try? await provider.realtime("grok-voice").doCreateClientSecret()
        let requests = await transport.requests
        #expect(requests.count == 10)
        #expect(await sequence.count == 10)
        for (index, request) in requests.enumerated() {
            #expect(request.headers.values.contains(where: { $0.contains("rotating-\(index + 1)") }))
            #expect(!request.headers.values.contains(where: { $0.contains("__swift_ai_credential_") }))
        }
    }

    @Test func streamingTranscriptionResolvesAtConnectAndPreservesHeaderOverride() async throws {
        let sequence = WeeklyCredentialSequence()
        let provider = try XAIProvider(configuration: .init(apiKeyProvider: { await sequence.next() }))
        #expect(await sequence.count == 0)
        for override in [false, true, false] {
            let socket = RealtimeTestWebSocketTransport()
            let input = AsyncThrowingStream<Data, Error>.makeStream()
            let model = try provider.streamingTranscriptionModel(webSocketTransport: socket)
            let result = try await model.stream(.init(audio: AIStreamingAudioInput(input.stream), inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16000), headers: override ? ["Authorization": "Bearer override-key"] : [:]))
            let request = try #require(socket.requests().first)
            let count = await sequence.count
            #expect(normalizeHeaders(request.headers)["authorization"] == (override ? "Bearer override-key" : "Bearer rotating-\(count)"))
            #expect(!request.headers.values.contains { $0.contains("__swift_ai_credential_") })
            result.cancel()
            input.continuation.finish()
        }
        #expect(await sequence.count == 2)
    }
}
