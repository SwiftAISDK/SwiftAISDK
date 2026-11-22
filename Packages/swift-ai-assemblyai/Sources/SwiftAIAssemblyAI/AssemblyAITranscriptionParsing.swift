import SwiftAIProvider

func assemblyAITranscriptionSegments(from raw: JSONValue) -> [TranscriptionSegment] {
    // Upstream maps every validated word, including empty text; timings are ms.
    raw["words"]?.arrayValue?.compactMap { item in
        guard let text = item["text"]?.stringValue,
              let start = item["start"]?.doubleValue,
              let end = item["end"]?.doubleValue else { return nil }
        return TranscriptionSegment(text: text, startSecond: start / 1000, endSecond: end / 1000)
    } ?? []
}
