# SwiftAIGoogleVertex

Swift-native port of Vercel AI SDK Google Vertex adapters. Canonical sources are exported as an independent Swift package. Dependencies share Google, Anthropic
and compatible/OpenAI wire implementations rather than copying them.

```swift
import SwiftAIGoogleVertex
let provider = try AIProviders.googleVertex(configuration: GoogleVertexProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

The reviewed upstream baseline is `@ai-sdk/google-vertex` 5.0.134. Gemini
transcription model IDs route to `generateContent`; Chirp and telephony models
retain Cloud Speech routing. Shared word timing requests enable `wordTimestamp`
unless the provider option explicitly disables it. Valid timings appear in
`result.words` and the existing `segments`; segment-only timing requests and
missing requested word timings produce warnings. Options use the first present
`googleVertex`, `vertex`, then `google` namespace.

```swift
let transcription = try provider.transcriptionModel("gemini-3.5-transcribe")
let result = try await transcription.transcribe(.init(
    audio: audioData,
    timestampGranularities: [.word]
))
let live = try provider.streamingTranscriptionModel("gemini-3.5-transcribe-live")
```

Live transcription uses native authenticated WebSockets with 16 kHz PCM audio,
project/location and OAuth credentials. Audio waits for `setupComplete`; interim
text can be revised before final segments. Finish retains provider usage and
language, and cancellation closes the socket and stops input. A quiet three-second
grace window handles servers that omit a terminal signal after audio ends.
`GoogleVertexProvider` accepts an injectable `webSocketTransport`.

Ordinary automatic Vertex-hosted Anthropic native structured output requires
`GoogleVertexHostedProviderSettings.supportsNativeStructuredOutput = true`, a
Claude 4.5+ versioned model ID and a Google Cloud organization policy allowing
`structured_outputs`. It defaults to false and never enables strict tool inputs.
The shared Anthropic explicit `outputFormat` mode and lossless native fallback
for models rejecting forced JSON tools retain their precedence over this
automatic-selection flag.
Shared Google improvements also preserve signed text/function-call order, map
speech language and enforce `toolChoice: none`. The four known Gemini image IDs,
including `gemini-nano-banana-2.1`, declare file input support. Catalog metadata
remains descriptive; it does not prove that a live account enables a feature.

MaaS image downloads and redirects use the shared origin-scoped download policy;
provider credentials are excluded from foreign image origins. Mock tests cover
these contracts. No live account or browser media behavior has been verified.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/google-vertex.md) for authentication, options and supported surfaces.
