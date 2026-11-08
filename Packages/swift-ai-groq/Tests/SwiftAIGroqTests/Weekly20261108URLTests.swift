import Foundation
import Testing
@testable import SwiftAIGroq
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261108 Groq native URL transcription")
struct Weekly20261108URLTests {
    @Test(arguments: [false, true])
    func plainTextResponseWorksForUploadedAndRemoteAudio(_ remote: Bool) async throws {
        let transport = RecordingTransport(response: .init(statusCode: 200, headers: ["content-type": "text/plain"], body: Data("Plain transcript".utf8)))
        let provider = try GroqProvider(configuration: .init(apiKey: "key", transport: transport))
        let model = try provider.transcriptionModel("whisper-large-v3")
        let options: [String: JSONValue] = ["groq": ["responseFormat": "text"]]
        let result: TranscriptionResult
        if remote { result = try #require(await model.transcribeFromURL(.init(audio: URL(string: "https://example.com/audio")!, providerOptions: options))) }
        else { result = try await model.transcribe(.init(audio: Data("audio".utf8), providerOptions: options)) }
        #expect(result.text == "Plain transcript")
        #expect(result.rawValue == "Plain transcript")
        let sent = try #require(await transport.requests().first)
        #expect(String(decoding: try #require(sent.body), as: UTF8.self).contains("text"))
    }

    @Test(arguments: [
        (400, "invalid audio file"),
        (401, "failed to retrieve media: received status code: 302"),
        (400, "failed to retrieve media: received status code: 3020")
    ])
    func otherFailuresNeverDeclineToFallback(_ status: Int, _ message: String) async throws {
        let body = try JSONEncoder().encode(JSONValue.object(["error": ["message": .string(message)]]))
        let transport = RecordingTransport(response: .init(statusCode: status, body: body))
        let provider = try GroqProvider(configuration: .init(apiKey: "key", transport: transport))
        do {
            _ = try await provider.transcriptionModel("whisper-large-v3").transcribeFromURL(.init(audio: URL(string: "https://example.com/audio")!))
            Issue.record("Expected provider failure")
        } catch AIError.apiCall(let error) {
            #expect(error.statusCode == status)
            #expect(error.message == message)
        }
    }

    @Test func URLIsSentWithoutUploadingOrDownloadingAndFragmentIsRemoved() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"text":"Hello","x_groq":{"id":"request"}}"#))
        let provider = try GroqProvider(configuration: .init(apiKey: "key", transport: transport))
        let url = URL(string: "https://storage.example.com/audio.mp3#fragment")!
        let result = try await provider.transcriptionModel("whisper-large-v3-turbo").transcribeFromURL(.init(audio: url))
        #expect(result?.text == "Hello")
        let request = try #require(await transport.requests().first)
        let body = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(body.contains("name=\"url\""))
        #expect(body.contains("https://storage.example.com/audio.mp3"))
        #expect(!body.contains("fragment"))
        #expect(!body.contains("name=\"file\""))
        #expect(url.fragment == "fragment")
        #expect(await transport.requests().count == 1)
    }
    @Test(arguments: [301, 302, 303, 307, 308, 404])
    func onlyProviderRedirectLimitationDeclinesToCoreFallback(_ redirect: Int) async throws {
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 400, body: Data("{\"error\":{\"message\":\"failed to retrieve media: received status code: \(redirect)\"}}".utf8)))
        let provider = try GroqProvider(configuration: .init(apiKey: "key", transport: transport))
        let model = try provider.transcriptionModel("whisper-large-v3-turbo")
        if redirect == 404 {
            await #expect(throws: AIError.self) { try await model.transcribeFromURL(.init(audio: URL(string: "https://example.com/audio")!)) }
        } else { #expect(try await model.transcribeFromURL(.init(audio: URL(string: "https://example.com/audio")!)) == nil) }
    }
    @Test(arguments: ["ftp://example.com/audio", "https://user:secret@example.com/audio"])
    func invalidURLsStopBeforeHTTP(_ value: String) async throws {
        let transport = RecordingTransport(responses: [])
        let provider = try GroqProvider(configuration: .init(apiKey: "key", transport: transport))
        await #expect(throws: AIError.self) { try await provider.transcriptionModel("whisper-large-v3").transcribeFromURL(.init(audio: URL(string: value)!)) }
        #expect(await transport.requests().isEmpty)
    }
}
