import Foundation
import Testing
@testable import SwiftAIAssemblyAI
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261108 AssemblyAI flat errors")
struct Weekly20261108ErrorTests {
    @Test(arguments: [0, 1, 2])
    func flatErrorIsPreservedOnUploadSubmitAndPoll(_ stage: Int) async throws {
        var responses = [AIHTTPResponse]()
        if stage > 0 { responses.append(jsonResponse(#"{"upload_url":"https://cdn.example.com/audio.wav"}"#)) }
        if stage > 1 { responses.append(jsonResponse(#"{"id":"job","status":"queued"}"#)) }
        responses.append(AIHTTPResponse(statusCode: 401, headers: ["x-request-id": "request"], body: Data(#"{"error":"Invalid API key","status":"unexpected"}"#.utf8)))
        let transport = RecordingTransport(responses: responses)
        let provider = try AssemblyAIProvider(configuration: .init(apiKey: "key", transport: transport))
        await #expect(throws: AIError.apiCall(provider: "assemblyai.transcription", statusCode: 401, body: "Invalid API key", headers: ["x-request-id": "request"])) {
            try await provider.transcriptionModel("best").transcribe(.init(audio: Data("audio".utf8)))
        }
        #expect(await transport.requests().count == stage + 1)
    }
}
