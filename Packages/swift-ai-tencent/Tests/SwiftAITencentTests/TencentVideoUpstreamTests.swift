import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAITencent

struct TencentVideoFixture: Sendable, CustomStringConvertible {
    let raw: JSONValue
    var description: String { "\(raw["model"]?.stringValue ?? "") / \(raw["name"]?.stringValue ?? "")" }
}
private let videoFixtures = try! decodeJSONBody(Data(tencentUpstreamVideoFixtures.utf8)).arrayValue!.map { TencentVideoFixture(raw: $0) }

@Suite("Tencent video release-matched upstream scenarios")
struct TencentVideoUpstreamTests {
    @Test(arguments: videoFixtures)
    func upstreamScenario(_ scenario: TencentVideoFixture) async throws {
        let fixture = scenario.raw
        let responseSpec = try #require(fixture["response"])
        let body = try #require(responseSpec["body"])
        let data: Data
        if let string = body.stringValue { data = Data(string.utf8) } else { data = try encodeJSONBody(body) }
        let response = AIHTTPResponse(statusCode: responseSpec["status"]?.intValue ?? 200,
            headers: ["content-type": "application/json", "x-test": "upstream"], body: data)
        let transport = TencentRecordingTransport(response)
        let model = try TencentVideoModel(modelID: try #require(fixture["model"]?.stringValue), configuration: tencentSettings(transport))
        #expect(model.providerID == "tencent.video")
        #expect(model.maxVideosPerCall == 1)
        if fixture["mode"] == "doStart" {
            let raw = try #require(fixture["options"])
            do {
                let result = try await model.startVideoGeneration(.init(request: try tencentVideoRequest(raw), webhookURL: raw["webhookUrl"]?.stringValue))
                #expect(fixture["error"] == nil)
                #expect(result.operation == (fixture["operation"] ?? ["taskId": "task-123"]))
                #expect(result.responseMetadata.timestamp == tencentTestDate)
                #expect(result.responseMetadata.modelID == model.modelID)
                #expect(result.responseMetadata.headers == response.headers)
                if let expectedWarnings = fixture["expectedWarnings"]?.arrayValue {
                    #expect(result.warnings.count == expectedWarnings.count)
                    for (actual, expected) in zip(result.warnings, expectedWarnings) {
                        if let feature = expected["feature"]?.stringValue { #expect(actual.feature == feature) }
                        if let details = expected["details"]?.stringValue { #expect(actual.message == details) }
                    }
                }
                if let expected = fixture["warningFeatures"]?.arrayValue {
                    #expect(result.warnings.compactMap(\.feature) == expected.compactMap(\.stringValue))
                    #expect(result.warnings.map(\.type) == Array(repeating: "unsupported", count: expected.count))
                }
            } catch {
                let expected = try #require(fixture["error"], "Unexpected error in \(fixture["name"]?.stringValue ?? "scenario"): \(error)")
                if case let AIError.apiCall(api) = error {
                    if let message = expected["error.message"]?.stringValue { #expect(api.message == message) }
                    if let status = expected["error.statusCode"]?.intValue { #expect(api.statusCode == status) }
                    if let retryable = expected["error.isRetryable"]?.boolValue { #expect(api.isRetryable == retryable) }
                    #expect(api.responseBody == String(decoding: data, as: UTF8.self))
                } else {
                    #expect(expected["message"] != nil)
                    #expect(String(describing: error).contains(try #require(expected["message"]?.stringValue)))
                }
            }
        } else {
            let result = try await model.videoGenerationStatus(.init(operation: ["taskId": "task-123"]))
            let actual: JSONValue
            switch result {
            case let .pending(_, _, metadata):
                #expect(metadata.timestamp == tencentTestDate); actual = ["status": "pending"]
            case let .failed(message, _, metadata):
                #expect(metadata.timestamp == tencentTestDate); actual = ["status": "error", "error": .string(message)]
            case let .completed(value):
                #expect(value.responseMetadata.timestamp == tencentTestDate)
                let videos: JSONValue = .array(value.videoURLDescriptors.map { ["type": "url", "url": .string($0.url), "mediaType": .string($0.mediaType ?? "video/mp4")] })
                #expect(value.videoURLDescriptors.map(\.url) == value.urls)
                actual = ["status": "completed", "videos": videos, "warnings": [], "providerMetadata": .object(value.providerMetadata)]
                if let expected = fixture["providerMetadata"] { #expect(.object(value.providerMetadata) == expected) }
                if let expected = fixture["videos"] { #expect(videos == expected) }
            }
            if let expected = fixture["expectedResult"] {
                let normalized = JSONValue.object(expected.objectValue?.filter { $0.key != "response" } ?? [:])
                if fixture["expectedResultStrict"] == true { #expect(actual == normalized) }
                else { tencentAssertSubset(actual, normalized) }
            }
        }
        let call = try #require(await transport.requests().first)
        if let expected = fixture["expectedBody"] {
            let actualBody = try decodeJSONBody(try #require(call.body))
            #expect(actualBody == expected, "Actual: \(actualBody); expected: \(expected)")
        }
        if let expected = fixture["expectedFiles"] { #expect(try decodeJSONBody(try #require(call.body))["FileInfos"] == expected) }
        if let expected = fixture["expectedURL"]?.stringValue { #expect(call.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == expected.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) }
        if let method = fixture["expectedMethod"]?.stringValue { #expect(call.method == method) }
        for (key, expected) in fixture["expectedHeaders"]?.objectValue ?? [:] { #expect(call.headers.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value == expected.stringValue) }
    }
    @Test(arguments: ["unknown-model", "vod/VS", "vod//2.0", "vod/VS/"])
    func rejectsUnsupportedIDs(_ id: String) {
        #expect(throws: AIError.unsupportedModel(provider: "tencent", capability: .video, modelID: id)) { try TencentVideoModel(modelID: id) }
    }
    @Test(arguments: ["WAITING", "PROCESSING"])
    func vodPending(_ status: String) async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": ["TaskType": "AigcVideoTask", "Status": .string(status)]]))
        let result = try await TencentVideoModel(modelID: "vod/VS/2.0", configuration: tencentSettings(transport)).videoGenerationStatus(.init(operation: ["taskId": "task-123"]))
        guard case .pending = result else { Issue.record("Expected pending for \(status)"); return }
    }
}
