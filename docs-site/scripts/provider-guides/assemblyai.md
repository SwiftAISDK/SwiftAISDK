## Quick start

```swift
import Foundation
import SwiftAISDK

let provider = try AIProviders.assemblyAI()
let model = try provider.transcriptionModel("universal-3-5-pro")
let audio = try Data(contentsOf: URL(fileURLWithPath: "meeting.mp3"))
let result = try await model.transcribe(audio: audio, fileName: "meeting.mp3", mimeType: "audio/mpeg")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIAssemblyAI`, then call
`AIProviders.assemblyAI(configuration: AssemblyAIProviderSettings(...))`; the
native factory requires the configuration argument.

Each call uploads the audio to `/v2/upload`, submits a transcript job and polls it
every 3 seconds. Polling gives up after 60 seconds, so very long recordings may
time out. See [Transcribe](../../core/transcribe/).

## Models

- `universal-3-5-pro`: current flagship model.
- `universal-3-pro` and `universal-2`: supported; return a warning recommending
  `universal-3-5-pro`.
- `best`: legacy model, sent as `speech_model`, with a deprecation warning.

All other IDs are sent in `speech_models`.

## Provider options

Pass options under `providerOptions["assemblyai"]`; types and ranges are validated
before upload.

```swift
let result = try await model.transcribe(
    audio: audio,
    fileName: "meeting.mp3",
    mimeType: "audio/mpeg",
    providerOptions: [
        "assemblyai": [
            "speakerLabels": true,
            "keytermsPrompt": ["SwiftAISDK", "Bedrock"],
            "sentimentAnalysis": true,
        ],
    ]
)
```

Supported keys include:

- Audio range and speakers: `audioStartFrom`, `audioEndAt` (milliseconds),
  `speakerLabels`, `speakersExpected`, `speakerOptions`, `multichannel`.
- Language: `languageCode` (or the shared `language` argument),
  `languageDetection`, `languageDetectionOptions`, `languageConfidenceThreshold`.
- Prompting: `prompt`, `keytermsPrompt`, `customSpelling`, `domain`,
  `temperature` (0–1), `speechThreshold` (0–1), `removeAudioTags` (`all` or
  `speaker`).
- Formatting: `punctuate`, `formatText`, `disfluencies`, `filterProfanity`.
- Audio intelligence: `autoChapters`, `autoHighlights`, `contentSafety`,
  `contentSafetyConfidence` (25–100), `entityDetection`, `iabCategories`,
  `sentimentAnalysis`, `summarization`, `summaryModel`, `summaryType`.
- PII redaction: `redactPii`, `redactPiiPolicies`, `redactPiiSub`,
  `redactPiiAudio`, `redactPiiAudioQuality`, `redactPiiAudioOptions`,
  `redactPiiReturnUnredacted`, `redactStaticEntities`.
- Webhooks: `webhookUrl`, `webhookAuthHeaderName`, `webhookAuthHeaderValue`.

Warnings point out invalid combinations: `wordBoost` and `boostParam` are
deprecated and rejected by Universal 3 models (use `keytermsPrompt`);
`languageDetection` cannot be combined with an explicit language code; and the
dependent redaction options need `redactPii` or `redactPiiAudio`.

## Results

Word timestamps are converted from milliseconds to seconds in `segments`.
Audio-intelligence output is returned under `providerMetadata["assemblyai"]`:
`utterances`, `sentimentAnalysisResults`, `entities`, `contentSafetyLabels`,
`iabCategoriesResult` and `autoHighlightsResult`. A transcript that finishes with
status `error` throws `AIError.invalidResponse` with AssemblyAI's message.

## Rotating credentials

`AssemblyAIProviderSettings` accepts an `apiKeyProvider` async throwing closure
that is called before each authenticated request (upload, submit and every poll).
A supplier error stops the request before it is sent.
