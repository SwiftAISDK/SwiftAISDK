import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAITencent

private actor TencentRotatingKey {
    private var count = 0
    func next() -> String { count += 1; return "key-\(count)" }
    func calls() -> Int { count }
}

@Suite("Tencent native integration supplements")
struct TencentNativeIntegrationTests {
    @Test func tokenHubResolvesRotatingKeyForStartAndStatus() async throws {
        let transport = TencentRecordingTransport(responses: [
            try tencentJSONResponse(["code": 0, "data": ["id": "task-123"]]),
            try tencentJSONResponse(["code": 0, "data": ["id": "task-123", "status": "processing"]])
        ])
        let key = TencentRotatingKey()
        let model = try createTencent(configuration: .init(apiKeyProvider: { await key.next() }, environment: [:], transport: transport)).video("kling-video-v3")
        #expect(await key.calls() == 0)
        let start = try await model.startVideoGeneration(.init(request: .init(prompt: "A cat")))
        _ = try await model.videoGenerationStatus(.init(operation: start.operation))
        let calls = await transport.requests()
        #expect(calls.map { $0.headers["authorization"] } == ["Bearer key-1", "Bearer key-2"])
        #expect(await key.calls() == 2)
    }
    @Test func tokenHubChatStreamingUsageAndLifecycle() async throws {
        let stream = #"""
        data: {"id":"chatcmpl-1","model":"hy4","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}

        data: {"id":"chatcmpl-1","model":"hy4","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":1,"total_tokens":4}}

        data: [DONE]


        """#
        let transport = TencentRecordingTransport(AIHTTPResponse(statusCode: 200, headers: ["content-type": "text/event-stream"], body: Data(stream.utf8)))
        let model = createTencent(configuration: .init(apiKey: "test-key", environment: [:], transport: transport)).chat("hy4")
        var parts: [LanguageStreamPart] = []
        for try await part in model.stream(.init(messages: [.user("Hi")])) { parts.append(part) }
        let text = parts.compactMap { part -> String? in
            if case let .textDeltaPart(_, delta, _) = part { return delta }; return nil
        }.joined()
        #expect(text == "Hello")
        #expect(parts.contains { if case let .finishMetadata(reason, usage, _) = $0 { return reason == "stop" && usage?.inputTokens == 3 }; return false })
        let call = try #require(await transport.requests().first)
        let body = try decodeJSONBody(try #require(call.body))
        #expect(body["stream"] == true)
        #expect(body["stream_options"] == ["include_usage": true])
    }
    @Test(arguments: [
        JSONValue.object(["tasksPriority": 11]), ["watermark": "true"], ["audio": "invalid"],
        ["elements": [["id": "missing-element"]]], ["assets": [["url": "asset://1", "category": "Document"]]]
    ])
    func rejectsMalformedOptionsBeforeSending(_ options: JSONValue) async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["code": 0, "data": ["id": "task-123"]]))
        let model = try TencentVideoModel(modelID: "kling-video-v3", configuration: tencentSettings(transport))
        await #expect(throws: AIError.self) { _ = try await model.startVideoGeneration(.init(request: .init(prompt: "A cat", providerOptions: ["tencent": options]))) }
        #expect(await transport.requests().isEmpty)
    }
    @Test func preAbortedStartAndStatusDoNotSend() async throws {
        let controller = AIAbortController(); controller.abort(reason: "stop")
        let transport = TencentRecordingTransport(try tencentJSONResponse(["code": 0, "data": ["id": "task-123"]]))
        let model = try TencentVideoModel(modelID: "kling-video-v3", configuration: tencentSettings(transport))
        await #expect(throws: AIAbortError(reason: "stop")) { _ = try await model.startVideoGeneration(.init(request: .init(prompt: "A cat", abortSignal: controller.signal))) }
        await #expect(throws: AIAbortError(reason: "stop")) { _ = try await model.videoGenerationStatus(.init(operation: ["taskId": "task-123"], abortSignal: controller.signal)) }
        #expect(await transport.requests().isEmpty)
    }
    @Test func vodMixedMediaTypesPreserveURLAssociations() async throws {
        let raw: JSONValue = ["TaskType": "AigcVideoTask", "Status": "FINISH", "AigcVideoTask": ["ErrCode": 0, "Output": ["FileInfos": [
            ["FileUrl": "https://vod.example.com/first.mov", "FileType": "MOV", "FileId": "file-1", "MetaData": ["Duration": 2.5]],
            ["FileUrl": "https://vod.example.com/second.webm", "FileType": "webm"],
            ["FileUrl": "https://vod.example.com/default.mp4", "FileType": ""],
            ["FileUrl": "https://vod.example.com/last.png", "UsageType": "last_frame_url"]
        ]]]]
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": raw]))
        let model = try TencentVideoModel(modelID: "vod/VS/2.0", configuration: tencentSettings(transport))
        let status = try await model.videoGenerationStatus(.init(operation: ["taskId": "task-123"]))
        guard case let .completed(result) = status else { Issue.record("Expected completed mixed-format VOD result"); return }
        #expect(result.videoURLDescriptors == [
            VideoURLDescriptor(url: "https://vod.example.com/first.mov", mediaType: "video/quicktime"),
            VideoURLDescriptor(url: "https://vod.example.com/second.webm", mediaType: "video/webm"),
            VideoURLDescriptor(url: "https://vod.example.com/default.mp4", mediaType: "video/mp4")
        ])
        #expect(result.urls == result.videoURLDescriptors.map(\.url))
        #expect(result.rawValue == raw)
        #expect(result.providerMetadata == ["tencent": ["taskId": "task-123", "lastFrameUrl": "https://vod.example.com/last.png", "videos": [
            ["url": "https://vod.example.com/first.mov", "fileId": "file-1", "duration": 2.5],
            ["url": "https://vod.example.com/second.webm"], ["url": "https://vod.example.com/default.mp4"]
        ]]])
    }

}
