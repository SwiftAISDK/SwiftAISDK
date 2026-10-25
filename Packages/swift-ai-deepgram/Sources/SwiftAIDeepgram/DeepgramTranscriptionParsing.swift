import SwiftAIProvider
import SwiftAIProviderUtilities




func deepgramTranscriptionSegments(from raw: JSONValue) -> [TranscriptionSegment] {
    transcriptionSegments(from: raw["results"]?["channels"]?[0]?["alternatives"]?[0]?["words"], textKey: "word")
}