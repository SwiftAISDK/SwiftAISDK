## Rotating API keys

`DeepgramProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.
## Native streaming transcription

`DeepgramProvider.streamingTranscriptionModel("nova-3")` (also
`streamingTranscription`) uses the v1 `/listen` WebSocket protocol. Feed raw PCM16,
μ-law (`audio/pcmu`) or A-law (`audio/pcma`) with an explicit positive sample rate
through `StreamingTranscriptionRequest`. Flux uses a different v2 protocol and
is rejected by this adapter.

Options under `deepgram.streaming` include `interimResults`, nonnegative integer
or false `endpointing`, `channels`, `multichannel`, `vadEvents` and
`utteranceEndMs` of at least 1000. Shared supported options keep their normal
namespace; unsupported active batch options warn. Batch transcription ignores
the streaming object with a warning.

Settings accept `webSocketTransport` injection. Credentials resolve once per
connection, keepalive runs while audio input is open, and finishing the input
sends `CloseStream`. Final text is ordered by time/channel; usage seconds come
only from provider metadata. Consumer cancellation closes the socket and audio
producer. `includeRawChunks` preserves unknown events.

Speech `callback` now rejects before I/O because asynchronous acknowledgement is
not an audio result. `callbackMethod` alone warns and is ignored. Use the REST
API directly when an asynchronous callback is required.
