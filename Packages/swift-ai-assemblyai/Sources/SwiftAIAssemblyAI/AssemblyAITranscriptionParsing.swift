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
    raw["words"]?.arrayValue?.compactMap { item in
        guard let text = item["text"]?.stringValue, !text.isEmpty else { return nil }
        let start = item["start"]?.doubleValue ?? 0
        let end = item["end"]?.doubleValue ?? start
        return TranscriptionSegment(text: text, startSecond: start / 1000, endSecond: end / 1000)
    } ?? []
}
