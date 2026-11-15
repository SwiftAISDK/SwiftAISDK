import Foundation
import CryptoKit
import SwiftAIProvider
import SwiftAITransport

struct TencentVodCredentials: Sendable {
    var secretId: String
    var secretKey: String
    var sessionToken: String?
    var subAppId: Double
}

func tencentSHA256(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
func tencentCanonicalRequest(payload: String, headers: [String: String]) -> (canonicalRequest: String, signedHeaders: String) {
    let entries = headers.map { ($0.key.lowercased(), $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }.sorted { $0.0 < $1.0 }
    let signed = entries.map(\.0).joined(separator: ";")
    return (["POST", "/", "", entries.map { "\($0.0):\($0.1)\n" }.joined(), signed, tencentSHA256(payload)].joined(separator: "\n"), signed)
}
func tencentTC3Authorization(secretId: String, secretKey: String, service: String, timestamp: Int, payload: String, headers: [String: String]) -> String {
    let formatter = ISO8601DateFormatter()
    let date = String(formatter.string(from: Date(timeIntervalSince1970: Double(timestamp))).prefix(10))
    let scope = "\(date)/\(service)/tc3_request"
    let canonical = tencentCanonicalRequest(payload: payload, headers: headers)
    let stringToSign = ["TC3-HMAC-SHA256", String(timestamp), scope, tencentSHA256(canonical.canonicalRequest)].joined(separator: "\n")
    func hmac(_ key: Data, _ value: String) -> Data { Data(HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: SymmetricKey(data: key))) }
    let dateKey = hmac(Data("TC3\(secretKey)".utf8), date)
    let serviceKey = hmac(dateKey, service)
    let signingKey = hmac(serviceKey, "tc3_request")
    let signature = hmac(signingKey, stringToSign).map { String(format: "%02x", $0) }.joined()
    return "TC3-HMAC-SHA256 Credential=\(secretId)/\(scope), SignedHeaders=\(canonical.signedHeaders), Signature=\(signature)"
}
func tencentCloudErrorStatus(_ code: String) -> Int {
    switch code.split(separator: ".").first.map(String.init) ?? "" {
    case "AuthFailure": return 401
    case "UnauthorizedOperation": return 403
    case "ResourceNotFound", "InvalidAction", "NoSuchProduct", "NoSuchVersion": return 404
    case "LimitExceeded", "RequestLimitExceeded": return 429
    case "InvalidParameter", "InvalidParameterValue", "InvalidRequest", "MissingParameter", "RequestSizeLimitExceeded", "UnknownParameter", "UnsupportedOperation", "UnsupportedProtocol", "UnsupportedRegion": return 400
    case "ResourceInsufficient", "ResourceUnavailable", "ServiceUnavailable": return 503
    case "FailedOperation": return code == "FailedOperation.InvalidVodUser" ? 403 : 500
    default: return 500
    }
}
func tencentCallError(_ response: AIHTTPResponse, message: String, status: Int? = nil, request: AIHTTPRequest? = nil, retryable: Bool? = nil) -> AIError {
    var error = AIAPICallError(provider: "tencent.video", url: request?.url.absoluteString,
        requestBody: request?.body.flatMap { try? decodeJSONBody($0) }, statusCode: status ?? response.statusCode,
        responseHeaders: response.headers, responseBody: response.bodyText, isRetryable: retryable)
    error.message = message
    return .apiCall(error)
}
func tencentVodCredentials(_ settings: TencentProviderSettings) throws -> TencentVodCredentials {
    let environment = settings.environment ?? ProcessInfo.processInfo.environment
    func load(_ value: String?, _ name: String) throws -> String {
        guard let result = value ?? environment[name] else { throw AIError.invalidArgument(argument: name, message: "Tencent Cloud setting is missing.") }
        return result
    }
    let raw = try load(settings.subAppId, "TENCENTCLOUD_VOD_SUB_APP_ID")
    guard let subAppId = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)), subAppId.isFinite,
          subAppId > 0, subAppId.rounded() == subAppId, subAppId <= 9_007_199_254_740_991 else {
        throw AIError.invalidArgument(argument: "subAppId", message: "Tencent VOD SubAppId must be a positive integer.")
    }
    return TencentVodCredentials(secretId: try load(settings.secretId, "TENCENTCLOUD_SECRET_ID"),
        secretKey: try load(settings.secretKey, "TENCENTCLOUD_SECRET_KEY"),
        sessionToken: settings.sessionToken ?? environment["TENCENTCLOUD_SESSION_TOKEN"], subAppId: subAppId)
}
func tencentPostCloud(settings: TencentProviderSettings, action: String, body: JSONValue, headers: [String: String], abortSignal: AIAbortSignal?, date: Date? = nil) async throws -> (JSONValue, AIHTTPResponse) {
    let credentials = try tencentVodCredentials(settings)
    let data = try tencentCloudPayload(body)
    let payload = String(decoding: data, as: UTF8.self)
    let url = try requireURL(withoutTrailingSlash(settings.vodBaseURL ?? tencentVodBaseURL))
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let host = components.host else { throw AIError.invalidURL(url.absoluteString) }
    let authority = host + (components.port.map { ":\($0)" } ?? "")
    let timestamp = Int((date ?? settings.currentDate()).timeIntervalSince1970)
    let authorization = tencentTC3Authorization(secretId: credentials.secretId, secretKey: credentials.secretKey, service: "vod", timestamp: timestamp, payload: payload,
        headers: ["content-type": "application/json; charset=utf-8", "host": authority, "x-tc-action": action.lowercased()])
    var protocolHeaders = ["authorization": authorization, "content-type": "application/json; charset=utf-8", "x-tc-action": action,
        "x-tc-timestamp": String(timestamp), "x-tc-version": "2018-07-17"]
    if let region = settings.region { protocolHeaders["x-tc-region"] = region }
    if let token = credentials.sessionToken { protocolHeaders["x-tc-token"] = token }
    var caller = normalizeHeaders(settings.headers).merging(normalizeHeaders(headers)) { _, new in new }
    caller = withUserAgentSuffix(caller, "ai-sdk-tencent/\(tencentProviderVersion)")
    caller = caller.filter { protocolHeaders[$0.key.lowercased()] == nil }.merging(protocolHeaders) { _, protocolValue in protocolValue }
    let request = AIHTTPRequest(method: "POST", url: url, headers: caller, body: data, abortSignal: abortSignal)
    try abortSignal?.throwIfAborted()
    let response = try await settings.transport.send(request)
    let raw = try? response.jsonValue()
    if !(200..<300).contains(response.statusCode) {
        let error = raw?["Response"]?["Error"]
        let message = error?["Code"]?.stringValue.flatMap { code in error?["Message"]?.stringValue.map { "\(code): \($0)" } } ?? response.bodyText
        throw tencentCallError(response, message: message, request: request)
    }
    guard let value = raw?["Response"], value.objectValue != nil, tencentOptional(value["RequestId"], kinds: [.string]) else { throw tencentCallError(response, message: "Invalid JSON response", request: request) }
    if let error = value["Error"], error != .null {
        guard let code = error["Code"]?.stringValue, let message = error["Message"]?.stringValue else { throw tencentCallError(response, message: "Invalid JSON response", request: request) }
        throw tencentCallError(response, message: "\(code): \(message)", status: tencentCloudErrorStatus(code), request: request)
    }
    return (value, response)
}
