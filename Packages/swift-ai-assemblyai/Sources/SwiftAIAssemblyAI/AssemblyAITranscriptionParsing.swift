import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



func assemblyAITranscriptionSegments(from raw: JSONValue) -> [TranscriptionSegment] {
    raw["words"]?.arrayValue?.compactMap { item in
        guard let text = item["text"]?.stringValue, !text.isEmpty else { return nil }
        let start = item["start"]?.doubleValue ?? 0
        let end = item["end"]?.doubleValue ?? start
        return TranscriptionSegment(text: text, startSecond: start / 1000, endSecond: end / 1000)
    } ?? []
}