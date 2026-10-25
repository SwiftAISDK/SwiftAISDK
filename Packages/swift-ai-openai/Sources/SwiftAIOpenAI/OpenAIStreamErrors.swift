import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
/// Normalizes OpenAI-owned stream error frames using the provider's published
/// code semantics. Chat and Completion pass the nested `error` object here;
/// Responses passes the complete event so `response.failed` can retain its
/// provider event type and raw payload.
public func openAIProviderStreamError(from frame: JSONValue) -> AIStreamProviderError? {
    let isResponseFailed = frame["type"]?.stringValue == "response.failed"
    let error = isResponseFailed
        ? frame["response"]?["error"]
        : frame["error"] ?? frame
    guard let error,
          let message = error["message"]?.stringValue else {
        return nil
    }

    let code: JSONValue?
    if error["code"]?.stringValue != nil || error["code"]?.doubleValue != nil {
        code = error["code"]
    } else {
        code = nil
    }
    let type = isResponseFailed ? "response.failed" : error["type"]?.stringValue
    guard isResponseFailed
            || frame["error"] != nil
            || type != nil
            || error["code"] != nil
            || error["param"] != nil else {
        return nil
    }

    let statusCode = openAIProviderStreamErrorStatusCode(code: code, type: type)
    let isInsufficientQuota = code?.stringValue == "insufficient_quota"
        || type == "insufficient_quota"
    return AIStreamProviderError(
        message: message,
        type: type,
        code: code,
        statusCode: statusCode,
        isRetryable: isInsufficientQuota
            ? false
            : statusCode == 408 || statusCode == 409 || statusCode == 429 || statusCode >= 500,
        data: frame
    )
}
func openAIProviderStreamAPICallError(
    _ error: AIStreamProviderError,
    providerID: String
) -> AIError {
    .apiCall(AIAPICallError(
        provider: providerID,
        statusCode: error.statusCode ?? 500,
        responseBody: error.message,
        isRetryable: error.isRetryable
    ))
}
private func openAIProviderStreamErrorStatusCode(code: JSONValue?, type: String?) -> Int {
    if let explicitStatusCode = openAIProviderHTTPStatusCode(code) {
        return explicitStatusCode
    }

    let discriminator = [code?.stringValue, type]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    if discriminator.contains("insufficient_quota") || discriminator.contains("rate_limit") {
        return 429
    }
    if discriminator.contains("authentication") { return 401 }
    if discriminator.contains("permission") { return 403 }
    if discriminator.contains("not_found") { return 404 }
    if discriminator.contains("invalid")
        || discriminator.contains("bad_request")
        || discriminator.contains("context_length") {
        return 400
    }
    if discriminator.contains("overload") { return 503 }
    if discriminator.contains("timeout") { return 504 }
    return 500
}
private func openAIProviderHTTPStatusCode(_ value: JSONValue?) -> Int? {
    if case let .number(number)? = value,
       number.isFinite,
       number.rounded(.towardZero) == number,
       (400.0...599.0).contains(number) {
        return Int(number)
    }
    if let string = value?.stringValue,
              string.count == 3,
              string.allSatisfy(\.isNumber),
       let statusCode = Int(string),
       400...599 ~= statusCode {
        return statusCode
    }
    return nil
}
