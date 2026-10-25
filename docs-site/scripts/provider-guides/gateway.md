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
