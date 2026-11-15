## Quick start

```swift
import Foundation
import SwiftAISDK

let provider = try AIProviders.gladia()
let model = try provider.transcriptionModel()

let audio = try Data(contentsOf: URL(fileURLWithPath: "interview.mp3"))
let result = try await model.transcribe(audio: audio, fileName: "interview.mp3", mimeType: "audio/mpeg")
print(result.text)
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIGladia`
with the native factory `AIProviders.gladia(configuration: GladiaProviderSettings())`.
The native factory requires the configuration argument; `GladiaProviderSettings()`
reads `GLADIA_API_KEY` from the environment. Requests authenticate with the
`x-gladia-key` header.

## Models

`transcriptionModel()` (and the `"default"` model ID) lets Gladia choose its
default model and sends no model field. Any other ID, such as `solaria-3`, is
sent as-is. Solaria 3 expects exactly one language and no code switching; other
settings produce warnings.

## How a transcription runs

1. Local audio is uploaded to `/v2/upload`.
2. A job is created at `/v2/pre-recorded`.
3. The SDK polls the result URL Gladia returns until the job is `done` or `error`.
   Credentials are sent only to Gladia-origin result URLs.

Polling defaults to every second with a 10-minute timeout. Set
`pollIntervalMs` and `pollTimeoutMs` (positive integers) on
`GladiaProviderSettings` or per call under `providerOptions["gladia"]`; per-call
values win. Polling honors the request's abort signal.

Results include text, detected language, segments (utterances) and duration.
Unknown add-on result fields are kept in provider metadata.

### Remote audio

To transcribe a file that is already online, pass its HTTP(S) URL. Gladia fetches
it directly and the upload step is skipped:

```swift
let result = try await AI.transcribe(
    model: model,
    request: AudioURLTranscriptionRequest(
        audio: URL(string: "https://example.com/interview.mp3")!
    )
)
```

## Provider options

Options under `providerOptions["gladia"]` use camelCase and are sent as snake_case:

```swift
let result = try await model.transcribe(
    audio: audio,
    mimeType: "audio/mpeg",
    providerOptions: ["gladia": [
        "languageConfig": ["languages": ["en", "fr"], "codeSwitching": true],
        "diarization": true,
        "diarizationConfig": ["numberOfSpeakers": 2],
        "customVocabulary": true,
        "customVocabularyConfig": ["vocabulary": ["SwiftAISDK"]],
    ]]
)
```

- Languages: use `languageConfig.languages` and `languageConfig.codeSwitching`.
  The legacy `language`, `detectLanguage`, `enableCodeSwitching` and
  `codeSwitchingConfig` keys are translated with deprecation warnings; an explicit
  `languageConfig` wins.
- Vocabulary: Boolean `customVocabulary` plus `customVocabularyConfig.vocabulary`.
  Legacy vocabulary arrays are translated, and invalid entries produce warnings.
- Add-ons such as `diarization`, `translation`, `summarization`, `subtitles`,
  `piiRedaction`, `namedEntityRecognition`, `sentimentAnalysis`, `customSpelling`,
  `audioToLlm` and `callback` take matching `...Config` objects; `customMetadata`
  is passed through. PII, translation and audio-to-LLM settings are
  validated before upload.
- Settings the Gladia v2 API no longer supports (`contextPrompt`, `moderation`,
  `chapterization`, `nameConsistency`, `structuredDataExtraction`, `displayMode`
  and `diarizationConfig.enhanced`) produce a warning and are ignored.

The `x-gladia-version` header defaults to the SDK's version string; set your own
value in `headers` to override it.

## Rotating credentials

`GladiaProviderSettings(apiKeyProvider:)` takes an async throwing closure that is
called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
