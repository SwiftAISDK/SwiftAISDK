import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

func assemblyAIHTTPStatusError(provider: String, response: AIHTTPResponse) -> AIError {
    // Existing transcription callers expect the explanatory text in responseBody.
    let flat = (try? response.jsonValue())?["error"]?.stringValue
    return apiCallError(provider: provider, statusCode: response.statusCode,
        body: flat ?? audioProviderErrorMessage(from: response.body) ?? response.bodyText,
        headers: response.headers)
}

func assemblyAIErrorData(from raw: JSONValue) -> JSONValue? {
    guard let error = raw["error"] else { return nil }
    if error.stringValue != nil { return .object(["error": error]) }
    guard let message = error["message"], message.stringValue != nil,
          let code = error["code"], code.doubleValue != nil else { return nil }
    return .object(["error": .object(["message": message, "code": code])])
}

func assemblyAISpeechHTTPError(response: AIHTTPResponse, request: AIHTTPRequest, requestBody: JSONValue, message: String? = nil) -> AIError {
    let data = (try? response.jsonValue()).flatMap(assemblyAIErrorData(from:))?["error"]
    var error = AIAPICallError(
        provider: "assemblyai.speech",
        url: request.url.absoluteString,
        requestBody: requestBody,
        statusCode: response.statusCode,
        responseHeaders: response.headers,
        responseBody: response.bodyText
    )
    error.message = message ?? data?.stringValue ?? data?["message"]?.stringValue
        ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode).capitalized(with: Locale(identifier: "en_US_POSIX"))
    return .apiCall(error)
}
