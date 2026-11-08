## Streaming transcription and current image options

`streamingTranscriptionModel(_:webSocketTransport:)` uses an injectable WebSocket transport. Audio format, sample rate, VAD, partial/final utterances, multi-channel input, finish metadata and producer cancellation follow the published xAI streaming contract. `opus` is also accepted for batch transcription. The requested model ID is retained by transcription factories.

Image capabilities recognize `grok-imagine-image-2.0`; options add 1.5k resolution and auto quality. X Search permits up to 20 allowed/excluded handles. Portable reasoning `max` maps to the provider's highest effort. Existing realtime sessions and Responses calls keep their separate native APIs.

## Rotating credentials

The native `XAIProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.

## Current reasoning and stream completion

Shared reasoning `none` maps to `low` with a compatibility warning on current
Grok 4.5, 4.6, 4.7 and 5-family models that cannot disable reasoning. Older
families, `grok-latest` and Grok 4.20 multi-agent retain their existing `none`
behavior. Exact `grok-4.6` maps portable `xhigh` and `max` to `xhigh`; other
models, including `grok-4.7`, currently map them to `high`. Explicit
`xai.reasoningEffort` provider options pass through unchanged.

Responses streams emit citation sources once when incremental annotations are
also repeated in the final output item. Completion-only message items retain
both text and citations, including when an item was announced without deltas.

`XAIProviderSettings.apiKeyProvider` accepts an async throwing key supplier.
It refreshes authentication before native language, files, batch, image, speech,
transcription, video polling and realtime client-secret HTTP requests, and
before each native streaming-transcription WebSocket connection. Static
keys and caller header overrides remain supported; browser-specific transport
and TypeScript catalog mechanics keep their documented native differences.

## Server realtime and caller-storage video

Server realtime connections derive their WebSocket URL from the configured base
path and resolve current credentials before connecting. The client-secret route
retains its canonical `/v1` URL. Conversation intent is supported; transcription
intent fails before I/O. Read normalized usage through `event.usage`, including
cached/modality counts without automatically summing provider snapshots.

Video `output.uploadUrl` selects direct delivery to caller-owned HTTPS storage.
The native unary polling result returns `uploadedVideos` descriptors even when no
download URL exists. Signed upload URLs are removed from returned request/raw
metadata and diagnostics. This does not introduce persisted Async Video operations.
Transcription returns independent word timings and warns when requested timings
are unavailable.
