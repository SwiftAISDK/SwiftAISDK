Known `ink-whisper` and dated `ink-whisper-*` snapshots use REST batch
transcription. Every other current or future ID uses the existing streaming
protocol; select `streamingTranscriptionModel(...)` for those models.

## Rotating credentials

The native provider settings accept an optional `apiKeyProvider` asynchronous
throwing closure. The provider resolves it for each authenticated request;
static keys and explicit custom authentication headers remain supported.
Supplier failures stop the request before it reaches the transport.

## Current request and response behavior

Sonic speech accepts `volume` (0.5...2), a declared `emotion`, `locale`,
`normalization`, and `pronunciationDictionaryId` in `providerOptions.cartesia`.
`locale` overrides the generic language with a warning, and cannot be combined
with a provider-specific language. Speed, volume and emotion share one generation
configuration. Ink 2 streaming accepts repeated `keyterms` (at most 100),
`turnStartThreshold`, `turnEagerEndThreshold`, `turnEndThreshold` and integer
`turnEndTimeoutMs`. Turn thresholds are omitted with warnings when turn detection
is disabled. The documented 1200-character keyterm budget remains a service limit;
the published schema validates the count.
