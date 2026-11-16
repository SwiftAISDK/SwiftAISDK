import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities

func assemblyAIHTTPStatusError(provider: String, response: AIHTTPResponse) -> AIError {
    let flat = (try? response.jsonValue())?["error"]?.stringValue
    return apiCallError(provider: provider, statusCode: response.statusCode,
        body: flat ?? audioProviderErrorMessage(from: response.body) ?? response.bodyText,
        headers: response.headers)
}



func assemblyAITranscriptionSegments(from raw: JSONValue) -> [TranscriptionSegment] {
    // Upstream maps every validated word, including empty text; timings are ms.
    raw["words"]?.arrayValue?.compactMap { item in
        guard let text = item["text"]?.stringValue,
              let start = item["start"]?.doubleValue,
              let end = item["end"]?.doubleValue else { return nil }
        return TranscriptionSegment(text: text, startSecond: start / 1000, endSecond: end / 1000)
    } ?? []
}
