import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



func gladiaTranscriptionSegments(from raw: JSONValue) -> [TranscriptionSegment] {
    // Upstream maps every validated utterance, including empty text.
    (raw["result"]?["transcription"]?["utterances"]?.arrayValue ?? []).compactMap { utterance in
        guard let text = utterance["text"]?.stringValue,
              let start = utterance["start"]?.doubleValue,
              let end = utterance["end"]?.doubleValue else { return nil }
        return TranscriptionSegment(text: text, startSecond: start, endSecond: end)
    }
}