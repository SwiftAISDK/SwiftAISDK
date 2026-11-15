## Quick start

```swift
import SwiftAISDK

let prodia = try AIProviders.prodia()
let model = try prodia.imageModel("inference.flux-fast.schnell.txt2img.v2")
let result = try await model.generateImage("A lighthouse at dawn", size: "1024x1024")
print(result.base64Images.first ?? "")
```

For the modular packages, use `import SwiftAI` and `import SwiftAIProdia`, then
`try AIProviders.prodia(configuration: ProdiaProviderSettings(...))`. The native factory
requires a configuration argument; `ProdiaProviderSettings()` reads the key from the
environment.

Model IDs are Prodia job types, such as `inference.flux-fast.schnell.txt2img.v2`,
`inference.nano-banana.img2img.v2` or `inference.wan2-2.lightning.txt2vid.v0`. Every
model submits a job to `/v2/job?price=true` and reads a multipart response.

## Images

`size` must be `WIDTHxHEIGHT`; any other format is ignored with a warning. `seed` is
forwarded. Image editing inputs are not supported (`supportsFileInputs` and
`supportsMaskInputs` are `false`). Options under `providerOptions["prodia"]`:

| Option | Behavior |
| --- | --- |
| `steps` | Integer from 1 to 4. |
| `width`, `height` | Integers from 256 to 1920; override `size`. |
| `stylePreset` | One of `3d-model`, `analog-film`, `anime`, `cinematic`, `comic-book`, `digital-art`, `enhance`, `fantasy-art`, `isometric`, `line-art`, `low-poly`, `neon-punk`, `origami`, `photographic`, `pixel-art`, `texture`, `craft-clay`. |
| `loras` | Up to three LoRA ID strings. |
| `progressive` | Boolean. |

The image is returned in `base64Images`. `providerMetadata["prodia"]["images"]` holds
the job's `jobId`, `seed`, `elapsed`, `iterationsPerSecond`, timestamps and price
(`dollars`).

## Language models

```swift
let model = try prodia.languageModel("inference.nano-banana.img2img.v2")
let result = try await model.generateText("Turn this sketch into a watercolor.")
```

The prompt combines the system message with the latest user message, and the first
image in that user message (inline data or a URL) is uploaded as the job input. Responses can contain text and generated files; streaming
delivers the completed job as a single chunk. `providerOptions["prodia"]["aspectRatio"]`
accepts `1:1`, `2:3`, `3:2`, `4:5`, `5:4`, `4:7`, `7:4`, `9:16`, `16:9`, `9:21` or
`21:9`. Temperature, sampling, `seed`, `maxOutputTokens`, stop sequences, penalties,
tools, JSON response format and custom reasoning produce unsupported warnings.

## Videos

```swift
let video = try prodia.videoModel("inference.wan2-2.lightning.txt2vid.v0")
let result = try await video.generateVideo(
    "A paper boat drifting on a pond",
    providerOptions: ["prodia": ["resolution": "720p"]]
)
```

Pass `image` to send an image-to-video job as multipart input. Remote image URLs are
downloaded with private-network protection before upload. `providerOptions["prodia"]`
accepts `resolution`. The generated video is returned in `base64Videos`, with its
`mediaType` taken from the response part (`video/mp4` by default). The completed job ID
is `operationID`, and job details are under `providerMetadata["prodia"]["videos"]`.

## Rotating credentials

The native `ProdiaProviderSettings` accepts `apiKeyProvider`, an async throwing closure
resolved before each authenticated request. A supplier failure stops the request before
it is sent.
