# SwiftAIDeepgram

Swift-native port of `@ai-sdk/deepgram`, reviewed through npm 3.1.53. The canonical
SwiftAISDK repository owns all source edits; this repository is its deterministic
standalone export.

```swift
import SwiftAIDeepgram
import SwiftAIProvider

let provider = try DeepgramProvider(configuration: .init(apiKey: "..."))
let live = try provider.streamingTranscriptionModel("nova-3")
let result = try await live.stream(.init(
    audio: .chunks([pcm16Audio]),
    inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000),
    providerOptions: ["deepgram": .object([
        "language": "en",
        "streaming": .object(["interimResults": true, "endpointing": 300])
    ])]
))
for try await part in result.stream {
    // Consume partial/final transcripts, metadata and the final aggregate.
}
```

Streaming uses `/v1/listen` and accepts raw PCM16, μ-law (`audio/pcmu`) or A-law
(`audio/pcma`) bytes with an explicit positive sample rate. Flux uses a different
v2 protocol and is rejected. `AIStreamingAudioInput.makeStream()` supports a live
producer; finish its writer to send `CloseStream`, or cancel the result to stop
input and close the connection. Keepalive runs while input is open. Final text is
ordered by time and channel; usage seconds come only from provider metadata.
`includeRawChunks` preserves unknown provider events. Awaited native sends provide
transport backpressure. Settings accept an injected `AIDuplexWebSocketTransport`
and an async `apiKeyProvider`; per-call authorization overrides are honored.

Provider options under `deepgram.streaming` include `interimResults`,
`endpointing` (a nonnegative integer or false), `channels`, `multichannel`,
`vadEvents` and `utteranceEndMs` (at least 1000). Batch transcription ignores this
object with an unsupported warning. Shared options are filtered for streaming;
unsupported active batch options produce warnings.

Speech `callback` is rejected before making a request because Deepgram returns a
JSON acknowledgement instead of audio. `callbackMethod` alone is ignored with a
warning. Use the REST API directly for asynchronous callback delivery. Existing
batch transcription and speech factories remain available.

Run `swift test --package-path Packages/swift-ai-deepgram --no-parallel` from the
canonical checkout. `Porting/map.json` records reviewed coverage and native
adaptations. Live network/provider behavior is not part of the deterministic suite.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.
