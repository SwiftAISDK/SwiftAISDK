import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenResponses


public func quiverAIResponseErrorMetadata(_ error: JSONValue) -> OpenResponsesErrorMetadata {
    guard let number = error["status_code"]?.doubleValue,
          number.isFinite,
          number.rounded(.towardZero) == number,
          let statusCode = Int(exactly: number),
          (400...599).contains(statusCode) else {
        return OpenResponsesErrorMetadata()
    }
    return OpenResponsesErrorMetadata(statusCode: statusCode)
}


public func quiverAIFailedResponse(_ response: AIHTTPResponse) -> OpenResponsesFailedResponse {
    let raw = try? response.jsonValue()
    let message = raw?["message"]?.stringValue ?? response.bodyText
    return OpenResponsesFailedResponse(
        statusCode: response.statusCode,
        responseBody: message,
        isRetryable: response.statusCode == 429 || response.statusCode >= 500
    )
}