## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.fal()
let model = try provider.imageModel("fal-ai/flux/schnell")
let result = try await model.generateImage(
    "A cozy reading nook with warm light",
    aspectRatio: "16:9"
)
let base64 = result.base64Images.first
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIFal` with
the native factory `AIProviders.fal(configuration: FalProviderSettings())`. The
native factory requires the configuration argument; `FalProviderSettings()` reads
`FAL_API_KEY`, then `FAL_KEY`, from the environment. Requests authenticate with a
`Key` authorization header.

## Images

Image models call `https://fal.run/{model}`. Generated image URLs are downloaded,
so results carry both `urls` and `base64Images`.

- `size` (`"1024x768"`) or `aspectRatio` (`"1:1"`, `"16:9"`, `"9:16"`, `"4:3"`,
  `"3:4"`, `"16:10"`, `"21:9"` and their inverses) become `image_size`.
- `seed` and `count` are forwarded.
- `files` and `mask` are sent as data URIs. Only the first input image is used
  unless you set `useMultipleImages: true` for models that accept several images,
  such as `fal-ai/flux-2/edit`.

Options under `providerOptions["fal"]` use camelCase and are converted to
snake_case: `guidanceScale` (1–20), `numInferenceSteps` (1–50),
`enableSafetyChecker`, `syncMode`, `outputFormat` (`jpeg` or `png`), `strength`,
`acceleration` (`none`, `regular`, `high`), `safetyTolerance` (1–6), `imageUrl`
and `maskUrl`. Other keys are passed through. Snake_case spellings of these keys
still work but produce a deprecation warning.

Per-image metadata (including an `nsfw` flag when fal reports one) is returned in
`providerMetadata["fal"]["images"]`.

## Video

Video models submit to `https://queue.fal.run` and poll until the job finishes.

```swift
let video = try provider.videoModel("fal-ai/luma-dream-machine")
let result = try await video.generateVideo(
    "A paper boat drifting down a rain-soaked street",
    aspectRatio: "16:9",
    durationSeconds: 5,
    providerOptions: ["fal": ["pollTimeoutMs": 600_000]]
)
print(result.urls)
```

- `durationSeconds` is sent as a string such as `"5s"`; a single `image` is used
  as the start frame.
- Options: `loop`, `promptOptimizer`, `motionStrength` (0–1), `resolution`,
  `negativePrompt`, `pollIntervalMs` (default 2000) and `pollTimeoutMs` (default
  300000).
- One video per call. The media type falls back to `video/mp4`.
- Credentials are forwarded to response URLs on the fal origin and stripped from
  URLs on other hosts.

The model also supports asynchronous start/status operations and fal webhooks
through the shared facade; see [Generate video](../../core/generate-video/) for
`poll` and `webhook` options.

## Speech

```swift
let speech = try provider.speechModel("fal-ai/minimax/speech-02-hd")
let audio = try await speech.generateSpeech(
    "Thanks for calling.",
    voice: "voice-id",
    providerOptions: ["fal": ["language_boost": "English"]]
)
```

`voice` and `speed` are forwarded, and the returned audio URL is downloaded
without credentials. Model-specific options, such as `voice_setting`,
`audio_setting`, `language_boost` and `pronunciation_dict`, are validated and
passed through. `language` is not supported (use `language_boost`), and any
`format` other than `url` or `hex` falls back to `url` with a warning.

## Transcription

```swift
let whisper = try provider.transcriptionModel("fal-ai/wizper")
let transcript = try await whisper.transcribe(audio: audioData, mimeType: "audio/wav")
print(transcript.text)
```

Audio is sent as a data URI to the fal queue and polled to completion. Defaults:
`language: "en"`, `diarize: true`, `chunkLevel: "segment"`, `version: "3"`,
`batchSize: 64`. Override them, or set `numSpeakers`, under
`providerOptions["fal"]`; pass `null` to omit `diarize`, `chunkLevel`, `version`
or `batchSize`.

## Rotating credentials

`FalProviderSettings(apiKeyProvider:)` takes an async throwing closure that is
called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
