import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



/// Mirrors upstream: the duration is the latest text `end_ts` across all monologues (not the
/// latest segment end), and a trailing open segment ends at that running duration.
func revAITranscriptionSegmentsAndDuration(from raw: JSONValue) -> (segments: [TranscriptionSegment], durationInSeconds: Double) {
    var segments: [TranscriptionSegment] = []
    var duration = 0.0
    for monologue in raw["monologues"]?.arrayValue ?? [] {
        var currentText = ""
        var segmentStart = 0.0
        var hasStartedSegment = false
        for element in monologue["elements"]?.arrayValue ?? [] {
            currentText += element["value"]?.stringValue ?? ""
            guard element["type"]?.stringValue == "text" else { continue }
            if let end = element["end_ts"]?.doubleValue {
                duration = max(duration, end)
            }
            if !hasStartedSegment, let start = element["ts"]?.doubleValue {
                segmentStart = start
                hasStartedSegment = true
            }
            if let end = element["end_ts"]?.doubleValue, hasStartedSegment {
                let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(TranscriptionSegment(text: trimmed, startSecond: segmentStart, endSecond: end))
                }
                currentText = ""
                hasStartedSegment = false
            }
        }
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasStartedSegment, !trimmed.isEmpty {
            let end = duration > segmentStart ? duration : segmentStart + 1
            segments.append(TranscriptionSegment(text: trimmed, startSecond: segmentStart, endSecond: end))
        }
    }
    return (segments, duration)
}