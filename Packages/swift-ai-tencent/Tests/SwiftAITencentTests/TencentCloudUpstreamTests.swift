import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAITencent

@Suite("Tencent TC3 release-matched upstream scenarios")
struct TencentCloudUpstreamTests {
    let payload = #"{"Limit": 1, "Filters": [{"Values": ["unnamed"], "Name": "instance-name"}]}"#
    @Test func documentedPayloadHash() {
        #expect(tencentSHA256(payload) == "99d58dfbc6745f6747f36bfca17dee5e6881dc0428a0a36f96199342bc5b4907")
    }
    @Test func documentedCanonicalHash() {
        let result = tencentCanonicalRequest(payload: payload, headers: ["Host": "cvm.tencentcloudapi.com", "Content-Type": "application/json; charset=utf-8"])
        #expect(result.signedHeaders == "content-type;host")
        #expect(tencentSHA256(result.canonicalRequest) == "2815843035062fffda5fd6f2a44ea8a34818b0dc46f024b8b3786976a3adda7a")
    }
    let signedPayload = #"{"SubAppId":1500000000,"ModelName":"VS","ModelVersion":"2.0","Prompt":"A cat"}"#
    let expectedAuthorization = "TC3-HMAC-SHA256 Credential=AKIDEXAMPLEEXAMPLEEXAMPLE/2026-11-08/vod/tc3_request, SignedHeaders=content-type;host;x-tc-action, Signature=20bd5603a92b091b44b53c95c55b2e5f7687cf779aff39688d83229b7252409f"
    @Test func referenceVodSignature() {
        let actual = tencentTC3Authorization(secretId: "AKIDEXAMPLEEXAMPLEEXAMPLE", secretKey: "EXAMPLESECRETKEYEXAMPLESECRETKEY", service: "vod", timestamp: 1_794_120_000, payload: signedPayload,
            headers: ["content-type": "application/json; charset=utf-8", "host": "vod.intl.tencentcloudapi.com", "x-tc-action": "createaigcvideotask"])
        #expect(actual == expectedAuthorization)
    }
    @Test(arguments: [
        ("AuthFailure.SignatureFailure", 401), ("AuthFailure.SecretIdNotFound", 401),
        ("UnauthorizedOperation", 403), ("FailedOperation.InvalidVodUser", 403),
        ("ResourceNotFound", 404), ("InvalidParameterValue.SubAppId", 400), ("MissingParameter", 400),
        ("RequestLimitExceeded", 429), ("LimitExceeded", 429), ("ResourceUnavailable", 503),
        ("InternalError", 500), ("FailedOperation", 500), ("SomethingNew", 500)
    ])
    func errorFamilyMapping(_ code: String, _ status: Int) { #expect(tencentCloudErrorStatus(code) == status) }

    private func settings(_ transport: any AITransport) -> TencentProviderSettings {
        .init(secretId: "AKIDEXAMPLEEXAMPLEEXAMPLE", secretKey: "EXAMPLESECRETKEYEXAMPLESECRETKEY", subAppId: "1500000000", environment: [:], transport: transport,
            currentDate: { Date(timeIntervalSince1970: 1_794_120_000) })
    }
    @Test func protocolHeadersAndExactSignature() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": ["TaskId": "task-1", "RequestId": "req-1"]]))
        let body: JSONValue = ["SubAppId": 1_500_000_000, "ModelName": "VS", "ModelVersion": "2.0", "Prompt": "A cat"]
        let (value, _) = try await tencentPostCloud(settings: settings(transport), action: "CreateAigcVideoTask", body: body, headers: ["Content-Type": "text/plain", "x-custom": "value"], abortSignal: nil)
        #expect(value["TaskId"] == "task-1")
        let call = try #require(await transport.requests().first)
        #expect(call.url.absoluteString == "https://vod.intl.tencentcloudapi.com")
        #expect(String(decoding: try #require(call.body), as: UTF8.self) == signedPayload)
        #expect(call.headers["content-type"] == "application/json; charset=utf-8")
        #expect(call.headers["x-tc-action"] == "CreateAigcVideoTask")
        #expect(call.headers["x-tc-version"] == "2018-07-17")
        #expect(call.headers["x-tc-timestamp"] == "1794120000")
        #expect(call.headers["x-tc-region"] == nil)
        #expect(call.headers["x-custom"] == "value")
        #expect(call.headers["authorization"] == expectedAuthorization)
    }
    @Test func regionAndSessionHeaders() async throws {
        let transport = TencentRecordingTransport(try tencentJSONResponse(["Response": ["TaskId": "task-1"]]))
        var configuration = settings(transport); configuration.region = "ap-singapore"; configuration.sessionToken = "session-token"
        _ = try await tencentPostCloud(settings: configuration, action: "DescribeTaskDetail", body: ["TaskId": "task-1"], headers: [:], abortSignal: nil)
        let call = try #require(await transport.requests().first)
        #expect(call.headers["x-tc-region"] == "ap-singapore")
        #expect(call.headers["x-tc-token"] == "session-token")
    }
    @Test(arguments: [
        ("AuthFailure.SignatureFailure", "The provided credentials could not be validated.", 401, false),
        ("RequestLimitExceeded", "Too many requests.", 429, true)
    ])
    func envelopedErrors(_ code: String, _ message: String, _ status: Int, _ retryable: Bool) async throws {
        let raw: JSONValue = ["Response": ["Error": ["Code": .string(code), "Message": .string(message)], "RequestId": "req-1"]]
        let transport = TencentRecordingTransport(try tencentJSONResponse(raw))
        do {
            _ = try await tencentPostCloud(settings: settings(transport), action: "CreateAigcVideoTask", body: ["Prompt": "A cat"], headers: [:], abortSignal: nil)
            Issue.record("Expected enveloped API failure")
        } catch let AIError.apiCall(error) {
            #expect(error.statusCode == status)
            #expect(error.isRetryable == retryable)
            #expect(error.message == "\(code): \(message)")
            #expect(try decodeJSONBody(Data(error.responseBody.utf8)) == raw)
        }
    }
}
