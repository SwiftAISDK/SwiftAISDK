import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAITencent

actor TencentRecordingTransport: AIStreamingTransport {
    private var responses: [AIHTTPResponse]
    private var calls: [AIHTTPRequest] = []
    init(_ response: AIHTTPResponse) { responses = [response] }
    init(responses: [AIHTTPResponse]) { self.responses = responses }
    func requests() -> [AIHTTPRequest] { calls }
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        try request.abortSignal?.throwIfAborted()
        calls.append(request)
        return responses.count > 1 ? responses.removeFirst() : responses[0]
    }
    func stream(_ request: AIHTTPRequest) async throws -> AIHTTPStreamResponse {
        let response = try await send(request)
        return AIHTTPStreamResponse(statusCode: response.statusCode, headers: response.headers,
            body: AsyncThrowingStream { continuation in continuation.yield(response.body); continuation.finish() })
    }
}
func tencentJSONResponse(_ value: JSONValue, status: Int = 200) throws -> AIHTTPResponse {
    AIHTTPResponse(statusCode: status, headers: ["content-type": "application/json", "x-test": "upstream"], body: try encodeJSONBody(value))
}
let tencentTestDate = Date(timeIntervalSince1970: 1_794_096_000)
func tencentSettings(_ transport: any AITransport) -> TencentProviderSettings {
    .init(apiKey: "test-key", secretId: "AKIDEXAMPLE", secretKey: "EXAMPLESECRET", subAppId: "1500000000",
        headers: ["x-vod-header": "vod"], environment: [:], transport: transport, currentDate: { tencentTestDate })
}
func tencentInput(_ raw: JSONValue) throws -> ImageInputFile {
    if raw["type"]?.stringValue == "url" { return ImageInputFile(url: try #require(raw["url"]?.stringValue), mediaType: raw["mediaType"]?.stringValue) }
    let data: Data
    if let bytes = raw["data"]?["__bytes"]?.arrayValue { data = Data(bytes.compactMap { $0.intValue.flatMap(UInt8.init(exactly:)) }) }
    else {
        let encoded = try #require(raw["data"]?.stringValue)
        data = try #require(Data(base64Encoded: encoded))
    }
    return ImageInputFile(data: data, mediaType: raw["mediaType"]?.stringValue ?? "image/png")
}
func tencentVideoRequest(_ raw: JSONValue) throws -> VideoGenerationRequest {
    var request = VideoGenerationRequest(prompt: raw["prompt"]?.stringValue ?? "", aspectRatio: raw["aspectRatio"]?.stringValue,
        durationSeconds: raw["duration"]?.doubleValue, resolution: raw["resolution"]?.stringValue,
        fps: raw["fps"]?.doubleValue, generateAudio: raw["generateAudio"]?.boolValue,
        seed: raw["seed"]?.intValue, count: raw["n"]?.intValue, providerOptions: raw["providerOptions"]?.objectValue ?? [:])
    if let image = raw["image"] { request.image = try tencentInput(image) }
    request.frameImages = try (raw["frameImages"]?.arrayValue ?? []).map {
        let rawType = try #require($0["frameType"]?.stringValue)
        let frameType = try #require(VideoFrameType(rawValue: rawType))
        return VideoFrameImage(image: try tencentInput(try #require($0["image"])), frameType: frameType)
    }
    request.inputReferences = try (raw["inputReferences"]?.arrayValue ?? []).map(tencentInput)
    return request
}
func tencentAssertSubset(_ actual: JSONValue, _ expected: JSONValue) {
    if let object = expected.objectValue {
        for (key, value) in object where value != .string("__ANY__") { tencentAssertSubset(actual[key] ?? .null, value) }
    } else { #expect(actual == expected) }
}
