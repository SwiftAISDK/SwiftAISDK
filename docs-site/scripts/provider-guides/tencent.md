## Quick start

```swift
import SwiftAISDK

let tencent = AIProviders.tencent()
let model = try tencent.languageModel("hy4")
let result = try await model.generateText("Introduce Swift in one sentence.")
print(result.text)
```

For the modular packages, use `import SwiftAI` and `import SwiftAITencent`, then
`AIProviders.tencent(configuration: TencentProviderSettings(...))` or
`createTencent(configuration:)`. The native factory does not throw;
`createTencent` defaults to `TencentProviderSettings()`, and `tencent` is a default
provider instance.

The provider has two independent backends: TokenHub (chat and Kling video, API key) and
Tencent Cloud VOD (video, signed with Tencent Cloud credentials). Credentials are
loaded only when a request for that backend runs, so you never need unused keys.

## TokenHub chat

`languageModel(_:)`, `chat(_:)` and `chatModel(_:)` return an OpenAI-compatible chat
model (`TencentChatLanguageModel`) for TokenHub IDs such as `hy4` and `hy3`. Tools,
reasoning, usage, metadata and streaming follow the shared OpenAI-compatible chat
behavior. TokenHub defaults to `https://tokenhub-intl.tencentcloudmaas.com/v1`; set
`baseURL` to change it.

## TokenHub Kling video

```swift
let video = try await AI.generateVideo(
    model: tencent.video("kling-video-v3"),
    request: VideoGenerationRequest(
        prompt: "A cat walking on a beach",
        aspectRatio: "16:9",
        durationSeconds: 5,
        resolution: "1920x1080",
        generateAudio: true
    )
)
print(video.urls.first ?? "")
```

TokenHub accepts `kling-video-*` IDs and routes standard, omni and motion-control models
to their endpoints; V4 IDs with references, voices or unframed elements use omni
routing. Inputs include first/last frames, image and video references, inline bytes and
URLs. Audio references are ignored with a warning; use the `voices` option instead.
Custom FPS, a count above one, `seed`, model options and per-request webhooks produce
warnings. The provider `resolution` option overrides the shared resolution tier.

## Tencent Cloud VOD video

```swift
let vod = AIProviders.tencent(configuration: .init(
    secretId: "SECRET_ID", secretKey: "SECRET_KEY",
    subAppId: "1500000000", region: "ap-singapore"
))
var options = TencentVideoModelOptions()
options.negativePrompt = "dogs"
options.enhancePrompt = false
options.assets = [.init(url: "asset://asset-1", usage: "FirstFrame")]
let started = try await AI.startVideo(
    model: vod.video("vod/VS/2.0"),
    request: VideoGenerationRequest(prompt: "A cat", providerOptions: try options.providerOptions)
)
```

VOD model IDs have the form `vod/<ModelName>/<ModelVersion>`. Requests go to
`https://vod.intl.tencentcloudapi.com` (override with `vodBaseURL`) and are signed with
TC3-HMAC-SHA256; signed protocol headers cannot be overridden by caller headers.
`secretId`, `secretKey`, `subAppId` and `sessionToken` fall back to their
`TENCENTCLOUD_*` environment variables. The SubAppId is a decimal string holding a
positive integer. `region` is optional.

## Video options

`TencentVideoModelOptions` validates options and encodes them under
`providerOptions["tencent"]`; you can also pass the raw dictionary.

- Both backends: `resolution`, `referenceVideoType` (`feature`, `base`), `watermark`.
- TokenHub only: `audio` (`native`, `original`, `off`), `multiShot`,
  `characterOrientation` (`image`, `video`), `elements`, `voices`, `externalTaskId`.
- VOD only: `negativePrompt`, `enhancePrompt`, `inputRegion`, `sceneType`,
  `personGeneration`, `inputComplianceCheck`, `outputComplianceCheck`,
  `enhanceSwitch`, `offPeak`, `sessionId`, `sessionContext`, `tasksPriority`,
  `extInfo`, `assets`.

Options for the other backend are ignored with a warning.

## Video jobs and results

`AI.generateVideo` polls until the task finishes. To resume later, call
`AI.startVideo(model:request:)`, persist the returned `operation` (it holds the
`taskId`), and call `AI.getVideoStatus(model:operation:)`, which returns `.pending`,
`.completed` or `.failed`. Calling the model's `generateVideo` directly polls every five
seconds for up to ten minutes. An empty prompt is omitted from the request.

Completed results contain the video `urls` and `videoURLDescriptors`, which pair each URL
with its own media type (VOD can return mixed MOV, WebM and MP4 outputs; `mediaType`
reports the first). `providerMetadata["tencent"]` holds task and request IDs, duration,
resolution, the last-frame URL and billing usage when provided; VOD last-frame images
are metadata, not video outputs. Tencent Cloud error envelopes become API errors with the
matching status and retryability. See [Generate video](../../core/generate-video/).

## Rotating credentials

`TencentProviderSettings.apiKeyProvider` accepts an async throwing closure that supplies
a fresh TokenHub key before each authenticated request. A supplier failure stops the
request before it is sent.
