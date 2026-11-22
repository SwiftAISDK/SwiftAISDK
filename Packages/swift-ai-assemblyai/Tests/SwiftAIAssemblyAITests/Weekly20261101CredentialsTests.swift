import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIAssemblyAI

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

@Suite("Weekly20261101 assemblyai credentials")
struct Weekly20261101CredentialsTests {
    @Test func resolvesFreshCredentialOnlyWhenRequestIsSent() async throws {
        let sequence = WeeklyCredentialSequence()
        let transport = WeeklyCredentialProbe()
        let provider = try AssemblyAIProvider(configuration: AssemblyAIProviderSettings(apiKeyProvider: { await sequence.next() }, transport: transport))
        let model = try provider.transcriptionModel("best")
        #expect(await sequence.count == 0)
        for _ in 0..<2 { _ = try? await model.transcribe(AudioTranscriptionRequest(audio: Data([1, 2, 3]), mimeType: "audio/wav")) }
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(await sequence.count == 2)
        for (index, request) in requests.enumerated() {
            #expect(request.headers.values.contains(where: { $0.contains("rotating-\(index + 1)") }))
            #expect(!request.headers.values.contains(where: { $0.contains("__swift_ai_credential_") }))
        }
    }

    @Test func resolvesFreshCredentialForEverySpeechRequest() async throws {
        let sequence = WeeklyCredentialSequence()
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, body: Data([1, 2, 3])))
        let provider = try AssemblyAIProvider(configuration: .init(apiKeyProvider: { await sequence.next() }, transport: transport))
        let model = provider.speech("assemblyai-tts-1")
        #expect(await sequence.count == 0)

        for _ in 0..<2 {
            _ = try await model.speak(.init(text: "Hello, world!"))
        }

        let requests = await transport.requests()
        #expect(requests.map { $0.headers["authorization"] } == ["rotating-1", "rotating-2"])
        #expect(await sequence.count == 2)
    }
}
