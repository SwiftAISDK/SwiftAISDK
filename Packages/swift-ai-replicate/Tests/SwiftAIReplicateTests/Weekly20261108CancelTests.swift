import Foundation
import Testing
@testable import SwiftAIReplicate
import SwiftAIProvider
import SwiftAITransport

@Suite("Weekly20261108 Replicate cancellation")
struct Weekly20261108CancelTests {
    @Test func abortPreservesOriginalFailureAndCancelResolvesFreshCredentials() async throws {
        let abort = AIAbortController()
        let transport = WeeklyReplicateCancelTransport(abort: abort)
        let keys = WeeklyReplicateKeys()
        let provider = try ReplicateProvider(configuration: .init(
            apiKeyProvider: { await keys.next() }, baseURL: "https://replicate.example.com/custom/v1",
            transport: transport
        ))
        await #expect(throws: WeeklyReplicateError.originalPollFailure) {
            try await provider.imageModel("owner/model").generateImage(.init(
                prompt: "cat", headers: ["idempotency-key": "create-only", "x-private": "call-only"], abortSignal: abort.signal
            ))
        }
        for _ in 0..<1000 {
            if await transport.requests().contains(where: { $0.url.path.hasSuffix("/cancel") }) { break }
            await Task.yield()
        }
        let requests = await transport.requests()
        let cancel = try #require(requests.first { $0.url.path.hasSuffix("/cancel") })
        #expect(cancel.url.absoluteString == "https://replicate.example.com/custom/v1/predictions/pred%2Fid/cancel")
        #expect(cancel.headers["authorization"] == "Bearer fresh-3")
        #expect(cancel.headers["idempotency-key"] == nil)
        #expect(cancel.headers["x-private"] == nil)
        #expect(cancel.abortSignal == nil)
        #expect(!cancel.followRedirects)
        #expect(requests.allSatisfy { $0.url.host == "replicate.example.com" })
    }

    @Test(arguments: [0, 42])
    func videoSeedIncludingZeroIsForwarded(_ seed: Int) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"video","status":"succeeded","output":"https://cdn.example.com/video.mp4","urls":{"get":"https://api.replicate.com/v1/predictions/video"}}"#))
        let provider = try ReplicateProvider(configuration: .init(apiKey: "key", transport: transport))
        _ = try await provider.videoModel("owner/model").generateVideo(.init(prompt: "cat", seed: seed))
        let sent = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(sent.body))
        #expect(body["input"]?["seed"]?.intValue == seed)
    }

    @Test func timeoutCancelsAtTrustedOriginWithoutRepeatingPerCallHeaders() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"id":"owner/prediction id","status":"processing","output":null,"urls":{"get":"https://api.replicate.com/v1/predictions/id","cancel":"https://untrusted.example.com/steal"}}"#))
        let provider = try ReplicateProvider(configuration: .init(apiKey: "key", transport: transport))
        do {
            _ = try await provider.imageModel("black-forest-labs/flux-schnell").generateImage(.init(prompt: "cat", providerOptions: ["replicate": ["maxPollAttempts": 1, "pollIntervalMillis": 1]], headers: ["idempotency-key": "create-only", "x-private": "per-call"]))
            Issue.record("Expected polling limit")
        } catch { #expect(String(describing: error).contains("after 1 polling attempts")) }
        for _ in 0..<1000 {
            if await transport.requests().contains(where: { $0.url.path.hasSuffix("/cancel") }) { break }
            await Task.yield()
        }
        let cancel = try #require(await transport.requests().first { $0.url.path.hasSuffix("/cancel") })
        #expect(cancel.url.absoluteString == "https://api.replicate.com/v1/predictions/owner%2Fprediction%20id/cancel")
        #expect(cancel.method == "POST")
        #expect(cancel.headers["authorization"] == "Bearer key")
        #expect(cancel.headers["idempotency-key"] == nil)
        #expect(cancel.headers["x-private"] == nil)
        #expect(cancel.abortSignal == nil)
        #expect(cancel.followRedirects == false)
    }
}

private enum WeeklyReplicateError: Error, Equatable { case originalPollFailure, ignoredCancelFailure }

private actor WeeklyReplicateKeys {
    private var count = 0
    func next() -> String { count += 1; return "fresh-\(count)" }
}

private actor WeeklyReplicateCancelTransport: FixtureDownloadTransport {
    let abort: AIAbortController
    private var recorded: [AIHTTPRequest] = []
    init(abort: AIAbortController) { self.abort = abort }
    func requests() -> [AIHTTPRequest] { recorded }
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        recorded.append(request)
        if request.url.path.hasSuffix("/cancel") { throw WeeklyReplicateError.ignoredCancelFailure }
        if request.method == "GET" {
            abort.abort(reason: "Stop image polling")
            throw WeeklyReplicateError.originalPollFailure
        }
        return jsonResponse(#"{"id":"pred/id","status":"processing","output":null,"urls":{"get":"https://replicate.example.com/custom/v1/predictions/pred","cancel":"https://attacker.example.com/cancel"}}"#)
    }
}
