## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.blackForestLabs()
let model = try provider.imageModel("flux-pro-1.1")
let result = try await model.generateImage("A red fox in fresh snow", aspectRatio: "16:9")
print(result.urls)
```

With modular packages, `import SwiftAI` and `import SwiftAIBlackForestLabs`, then
call `AIProviders.blackForestLabs(configuration: BlackForestLabsProviderSettings(...))`;
the native factory requires the configuration argument.

Requests are submitted to `https://api.bfl.ai/v1/<model>` with an `x-key` header
and polled until the result is ready. Polling URLs returned by the API are only
sent your key when they belong to `bfl.ai`; signed result downloads never carry
provider credentials.

## Image models

Pass options under `providerOptions["blackForestLabs"]`; invalid values throw
before submission.

```swift
let result = try await model.generateImage(
    "A product shot of a ceramic mug",
    size: "1024x768",
    providerOptions: ["blackForestLabs": ["outputFormat": "png", "safetyTolerance": 2]]
)
```

Model IDs pick the request protocol:

- **FLUX 1/2 and Kontext** (for example `flux-pro-1.1`, `flux-pro-1.1-ultra`,
  `flux-2-pro`, `flux-pro-1.0-fill`): options `imagePrompt`, `imagePromptStrength`
  (0–1), `inputImage` … `inputImage10`, `steps`, `guidance`, `width`/`height`
  (256–1920), `outputFormat` (`jpeg`, `png`), `promptUpsampling`, `raw`,
  `safetyTolerance` (0–6), `webhookUrl`, `webhookSecret`.
- **`flux-3-image`**: up to ten reference images, `resolution` (`768sq`, `1k`,
  `1.5k`, `2k`, `4k`), `grounding`, `version` (`"latest"`) and `safetyTolerance`
  (0–7). `size` can derive an aspect ratio; an explicit `aspectRatio` wins. Seed
  and legacy fields are omitted with warnings; masks fail before submission.
- **`flux-3-image-klein` and unknown future IDs**: the latest image API with up to
  ten references, seed, PNG/JPEG output, `steps` (1–16) and `safetyTolerance`
  (0–7). `size` sends exact dimensions; `width`/`height` must be given together,
  each 64–6256, with at most 16,822,272 pixels. Masks are unsupported.

`pollIntervalMillis` and `pollTimeoutMillis` tune polling; the timeout is a
wall-clock deadline that aborts a hung request. Submission cost is returned in the
provider metadata.

## Video (FLUX 3)

```swift
let video = try provider.videoModel("flux-3-video")
let result = try await video.generateVideo(
    "A paper lantern drifting over a lake at night",
    aspectRatio: "16:9",
    durationSeconds: 8,
    resolution: "fhd"
)
print(result.urls)
```

- Resolution is `hd` or `fhd`; `WIDTHxHEIGHT` values are mapped to the nearest
  tier with a warning. Aspect ratios: `21:9`, `2:1`, `16:9`, `4:3`, `1:1`, `3:4`,
  `9:16`, `auto`.
- Duration is a whole number of seconds from 5 to 20; other values are rounded or
  clamped with a warning. Custom `fps`, `seed` and more than one video per call
  are not supported.
- Start from an image with `image` or first/last `frameImages`, or pass timed
  `keyframes` in provider options. Pass a video reference to continue an existing
  clip; image references are ignored with a warning.
- Provider options: `resolution`, `aspectRatio`, `keyframes`, `safetyTolerance`
  (0–4), `draft`, `draftCache`, `version`, `pollIntervalMillis`,
  `pollTimeoutMillis`. Draft enhancement replays the original draft settings.

The video model also supports the start/status operation flow, so a job can be
started, persisted and resumed in another process. Black Forest Labs has no native
webhooks; a supplied webhook produces a warning and the call polls instead. See
[Generate video](../../core/generate-video/).

## Rotating credentials

`BlackForestLabsProviderSettings` accepts an `apiKeyProvider` async throwing
closure that is called before each authenticated request, including polls. A
supplier error stops the request before it is sent.
