import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities



func gladiaTranscriptionSegments(from raw: JSONValue) -> [TranscriptionSegment] {
    transcriptionSegments(from: raw["result"]?["transcription"]?["utterances"])
}