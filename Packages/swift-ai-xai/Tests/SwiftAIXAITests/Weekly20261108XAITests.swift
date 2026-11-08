import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIXAI

@Suite struct Weekly20261108XAITests {
    @Test func nativeServerConnectionAndGrossUsageArePreserved() async throws {
        let provider = try XAIProvider(configuration: .init(apiKey: "key", baseURL: "http://localhost:8787/proxy/v1"))
        let model = try provider.experimentalRealtime("grok voice")
        let configuration = try await model.getResolvedServerWebSocketConfig(intent: .conversation)
        #expect(configuration.url == "ws://localhost:8787/proxy/v1/realtime?model=grok%20voice")
        #expect(configuration.headers["authorization"] == "Bearer key")
        await #expect(throws: AIError.self) { _ = try await model.getResolvedServerWebSocketConfig(intent: .transcription) }
        await #expect(throws: AIError.self) { _ = try await model.serializeClientEvent(.responseCancel, intent: .transcription) }
        #expect(throws: AIError.self) { _ = try model.buildSessionConfig(.init(), intent: .transcription) }
        let events = model.parseServerEvent(["type": "response.done", "response": ["id": "resp", "usage": [:]], "usage": ["input_tokens": 10, "output_tokens": 0, "input_token_details": ["cached_tokens": 4, "image_tokens": 10]]])
        #expect(events.first?.usage == .init(inputTokens: 10, outputTokens: 0, cachedInputTokens: 4))
        let duration = model.parseServerEvent(["type": "conversation.item.input_audio_transcription.completed", "item_id": "item", "transcript": "Hi", "usage": ["type": "duration", "seconds": 2]])
        #expect(duration.first?.usage == .init(seconds: 2))
    }

    @Test func transcriptionWordsAndUnsupportedSegmentsRemainDistinct() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"text":"hello","words":[{"text":"hello","start":0.1,"end":0.8}]}"#))
        let provider = try XAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.transcription().transcribe(.init(audio: Data([1]), timestampGranularities: [.word, .segment]))
        #expect(result.words == [.init(text: "hello", startSecond: 0.1, endSecond: 0.8)])
        #expect(result.segments == result.words)
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.feature == "timestampGranularities")
    }

    @Test func responsesIncompleteReasonAndClientToolsKeepUpstreamPrecedence() async throws {
        let raw = #"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[{"type":"message","id":"msg","content":[{"type":"output_text","text":"Partial"}]}]}"#
        let transport = RecordingTransport(response: jsonResponse(raw))
        let provider = try XAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.responses("grok-4.6").generate(.init(messages: [.user("Hi")]))
        #expect(result.finishReason == "length")
    }

    @Test func signedUploadDeliveryReturnsConfirmationWithoutLeakingURL() async throws {
        let signed = "https://storage.test/output.mp4?token=private"
        let transport = RecordingTransport(responses: [jsonResponse(#"{"request_id":"req"}"#), jsonResponse(#"{"status":"done","video":{"duration":3}}"#)])
        let provider = try XAIProvider(configuration: .init(apiKey: "key", transport: transport))
        let result = try await provider.videoModel("grok-imagine-video").generateVideo(.init(prompt: "Hi", providerOptions: ["xai": ["output": ["uploadUrl": .string(signed)], "pollIntervalMs": 1]]))
        let body = try decodeJSONBody(#require(await transport.requests().first?.body))
        #expect(body["output"]?["upload_url"] == .string(signed))
        #expect(result.urls.isEmpty); #expect(result.uploadedVideos == [.init(mediaType: "video/mp4")])
        #expect(!String(describing: result.rawValue).contains("private"))
        #expect(!String(describing: result.requestMetadata).contains("private"))
        #expect(result.providerMetadata["xai"]?["videoUrl"] == nil)
    }

    @Test func uploadURLValidationAndErrorRedactionPreserveRetrySemantics() async throws {
        for signed in ["http://storage.test/file?secret=token", "https://user:password@storage.test/file", "https://storage.test/file#secret"] {
            let transport = RecordingTransport(response: jsonResponse("{}"))
            let provider = try XAIProvider(configuration: .init(apiKey: "key", transport: transport))
            do { _ = try await provider.videoModel("video").generateVideo(.init(prompt: "Hi", providerOptions: ["xai": ["output": ["uploadUrl": .string(signed)]]]))
                Issue.record("Expected invalid upload URL")
            } catch { #expect(!String(describing: error).contains(signed)) }
            #expect(await transport.requests().isEmpty)
        }
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 429, body: Data("echo https://storage.test/file?secret=token".utf8)))
        let provider = try XAIProvider(configuration: .init(apiKey: "key", transport: transport))
        do { _ = try await provider.videoModel("video").generateVideo(.init(prompt: "Hi", providerOptions: ["xai": ["output": ["uploadUrl": "https://storage.test/file?secret=token"]]])); Issue.record("Expected API failure") }
        catch let AIError.apiCall(error) { #expect(error.isRetryable); #expect(error.statusCode == 429); #expect(!String(describing: error).contains("secret=token")) }
    }
}
