## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.fishAudio()
let model = try provider.speechModel("s2-pro")
let result = try await model.generateSpeech(
    "Hello from Fish Audio.",
    voice: "your-voice-reference-id",
    format: "wav"
)
let wav = result.audio
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIFishAudio`
with the native factory `AIProviders.fishAudio(configuration: FishAudioProviderSettings())`.
The native factory requires the configuration argument; `FishAudioProviderSettings()`
reads `FISH_AUDIO_API_KEY` from the environment (or from its `environment`
dictionary when set). Requests use bearer authentication.

## Speech

Speech calls `/v1/tts` and returns binary audio. The model ID (`s1`, `s2-pro`,
`s2.1-pro`) is sent in the `model` header.

- `voice` becomes `reference_id`; `providerOptions["fishAudio"]["referenceId"]`
  takes precedence and also accepts an array.
- `format`: `mp3` (default), `wav`, `pcm` or `opus`. Other values fall back to
  `mp3` with a warning.
- `speed` must be between 0.5 and 2; values outside the range are ignored with a
  warning.
- `language` and `instructions` are not supported and produce warnings. Fish Audio
  infers the language from the text and voice.

Options under `providerOptions["fishAudio"]`:

| Key | Values |
| --- | --- |
| `latency` | `low`, `normal`, `balanced` |
| `sampleRate`, `maxNewTokens` | Positive integers |
| `mp3Bitrate` | 64, 128 or 192 |
| `opusBitrate` | -1000, 24000, 32000, 48000 or 64000 |
| `volume`, `normalizeLoudness` | Prosody controls; `normalizeLoudness` applies to the S2 family and is ignored on `s1` with a warning |
| `temperature`, `topP`, `earlyStopThreshold` | 0–1 |
| `repetitionPenalty` | Number |
| `chunkLength` (100–300), `minChunkLength` (0–100) | Integers |
| `normalize`, `conditionOnPreviousChunks` | Booleans |
| `features` | Array of strings |

Invalid values fail before the request is sent.

## Transcription

Fish Audio has a single ASR model. The model ID is a local label and defaults to
`transcribe-1`.

```swift
let asr = try provider.transcription()
let transcript = try await asr.transcribe(
    audio: audioData,
    fileName: "memo.m4a",
    mimeType: "audio/mp4",
    providerOptions: ["fishAudio": ["language": "en"]]
)
print(transcript.text, transcript.segments.count)
```

Audio is uploaded as multipart to `/v1/asr`. Set `ignoreTimestamps: true` to skip
timed segments (the default is `false`). Results include text, language, duration
and segments; the detected display language is in
`providerMetadata["fishAudio"]["language"]`.

## Errors

Fish Audio `status`/`message` error bodies become typed API errors with the HTTP
status and response headers.

## Rotating credentials

`FishAudioProviderSettings(apiKeyProvider:)` takes an async throwing closure that
is called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
