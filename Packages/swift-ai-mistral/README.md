# SwiftAIMistral

Swift-native port of `@ai-sdk/mistral`, reviewed through npm 4.0.81. Source edits
belong to the canonical SwiftAISDK repository and are exported deterministically.

```swift
import SwiftAIMistral
import SwiftAIProvider

let provider = try MistralProvider(configuration: .init(apiKey: "..."))
let result = try await provider.streamingTranscriptionModel(
    "voxtral-mini-transcribe-realtime-3"
).stream(.init(
    audio: .chunks([pcm16Audio]),
    inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 24_000),
    providerOptions: ["mistral": .object(["targetStreamingDelayMs": 480])]
))
for try await part in result.stream {
    // Consume transcript deltas/finals, metadata and the final aggregate.
}
```

Native streaming transcription uses `/audio/transcriptions/realtime` with PCM16
and a positive sample rate (default 16000). It waits for the session handshake,
splits audio into 64 KiB frames, awaits each send, and finalizes only on
`transcription.done`. Cancellation, provider errors, invalid events and early
socket closure cancel input and close the socket. Untimed speaker segments are
preserved in provider metadata without fabricated timestamps. Usage is retained
unchanged; `includeRawChunks` exposes turn events and unknown messages.

Realtime options include `language`, `contextBias`, `diarize`,
`targetStreamingDelayMs` (80–1200 or 2400), `speakerReferences` and `turnDetection`.
The provider validates diarization/turn compatibility and speaker clip constraints.
Offline transcription warns and ignores the three realtime-only settings;
streaming warns and ignores offline-only return-language, temperature and timestamp
options. Settings accept an injected `AIDuplexWebSocketTransport`; async API keys
resolve separately for each connection.

`provider.voiceSessions.create(modelID:sessionConfiguration:)` creates a managed
voice agent through `/audio/sessions` and returns its ID, participant token and
server URL. `close(sessionID:)` deletes a session. The throwing
`buildSessionConfiguration(_:modelID:update:)` maps supported normalized settings
and strict `mistral` STT/TTS/turn/agent options, rejecting unsupported settings.
`MistralVoiceSessions.parseServerEvent(_:)` maps final user/assistant transcripts,
updates and errors; revised partials emit no appended text and unknown events are
preserved. These are server control and event-mapping APIs. The browser LiveKit
room, microphone, playback, tool RPC and reconnect transport is not implemented;
no managed voice server WebSocket route is advertised.

Chat supports native medium reasoning for `mistral-large-4`/`mistral-large-4-0` and
specific function choice while preserving all declared tools. Conversations keeps
its distinct tool-selection contract. Tool-call argument strings preserve valid
JSON verbatim; non-JSON strings are JSON-quoted. Swift `JSONValue` is a value tree,
so JavaScript BigInt/cyclic-object serialization has no corresponding input shape.

Run `swift test --package-path Packages/swift-ai-mistral --no-parallel` from the
canonical checkout. See `Porting/map.json` for exact reviewed scope and adaptations.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.
