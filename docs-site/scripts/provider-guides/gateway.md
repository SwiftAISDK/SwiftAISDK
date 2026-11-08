## Decisions, embeddings, and bounded batches

Use `decisionModel(...)` with [Decision](../../core/decide/); legacy Evaluation factories use the new `/decision-model` envelope while retaining Swift call signatures. Embedding calls forward generic dimensions. Provider/model catalogs accept decision entries as open strings.

Decision calls forward optional `maxOutputTokens` and `reasoning` to the selected Gateway model. Leave them unset to retain provider defaults; values such as `provider-default`, `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, and `max` pass through for the model to interpret.

Both provider-owned and language-model batch result routes use `ProviderSettings.batchResultDownloads`, defaulting to a 64 MiB limit per UTF-8 row. Oversized rows fail with `AIDownloadError` and cancel the producer.

When xAI/SpaceXAI diarization is requested but no nested raw speaker evidence is returned, transcription adds an unsupported-option warning. Existing provider metadata remains available for callers that receive speaker evidence.

## Streaming speech

`streamingSpeechModel("fish-audio/s2-pro")` or the existing `speechModel(...)`
factory can feed `AI.experimentalStreamSpeech`. Incremental text, speaker
boundaries, requested audio format, provider options and cancellation use the
native speech contract described in [Stream speech](../../core/stream-speech/).

On a trusted server, mint a speech-bound short-lived token:

```swift
let secret = try await gateway.experimentalSpeech.getToken(.init(
    model: "fish-audio/s2-pro", expiresAfterSeconds: 60
))
```

The result includes `token`, the speech WebSocket `url`, and optional `expiresAt`
in epoch seconds. Give the token to a client configured with its own Gateway
provider. Keep the server credential on the server. Speech connects with
`ai-gateway-speech.v1` plus the shared auth/team subprotocols. Unknown envelope
parts are ignored; typed server errors and premature close remain observable.

## Parallel Search

`GatewayTools.parallelSearch` accepts the current `turbo`, `fast`, `basic` and
`advanced` modes, plus the legacy `one-shot` and `agentic` aliases. Omitted mode
uses the server's `basic` default. `turbo` supports English and Japanese. Domain
filters may include paths, for example `docs.python.org/3`.

```swift
let search = GatewayTools.parallelSearch(
    mode: "fast",
    includeDomains: ["docs.python.org/3"],
    maxCharsTotal: 8_000,
    maxAgeSeconds: 600,
    timeoutSeconds: 10,
    disableCacheFallback: true,
    location: "jp"
)
```

`maxCharsTotal` is sent at the top level. `timeoutSeconds` and
`disableCacheFallback` configure fetch freshness; the service raises cache ages
below 600 seconds to 600. Search results retain their raw GA fields:
`search_id`, `results[].excerpts`, nullable titles/publication dates, optional
warnings, usage and `session_id`. Consumers that decoded the old camelCase
result fields should adopt the GA response names.

## Rotating credentials and cancellation

`GatewayProviderSettings.apiKeyProvider` accepts an async throwing supplier and
resolves a fresh nonempty key before each authenticated request or streaming
speech/transcription connection. Metadata failures use the credential already
resolved for that request; error classification does not invoke the supplier
again. Static API keys, OIDC fallback and caller header precedence remain
available.

Caller cancellation and timeout errors retain their native identity through
HTTP, client-secret requests and duplex speech/transcription. An upstream text
or audio input failure ends the output stream and closes its socket instead of
becoming a retryable Gateway 500. Native `AIAbortError`, task cancellation and
Foundation cancellation/timeout errors remain distinguishable from service
failures. Model identifiers stay open strings, including newly published
Gateway speech, transcription, realtime and language aliases.

## Native realtime, costs and uploaded assets

`GatewayProvider.realtimeModel("openai/gpt-realtime-2")` implements the normalized
Gateway WebSocket protocol. It supports ephemeral client-secret/team protocols
and trusted server connections with fresh headers via
`AIRealtimeSession.connectServer`. Transcription intent rejects before I/O;
streaming transcription retains its separate route. Usage remains in the raw
event envelope and is exposed through `event.usage`.

`GatewayTools.deepseekSearch` and `deepseekFetch` expose Gateway-executed tools.
Structured tool errors preserve retryAfter, statusText and additive fields in
generation and streams. Generation info adds optional marketCost, surchargeCost
and gatewayCost, preserving zero. Transcription returns independent words; the
shared timestampGranularities setting warns because the wire route cannot
forward it. Completed video outputs retain uploadedVideos without requiring
URLs or inline bytes.

An empty configured key falls through to current Vercel OIDC credentials; a
nonempty invalid key remains selected. The client-only
`gateway.experimental_streamingImageDecoding` flag is removed from the wire and
warns when true. Native image results remain buffered base64: the incremental
JSON/binary parser and reduced-memory result contract remain unimplemented.
