Known `ink-whisper` and dated `ink-whisper-*` snapshots use REST batch
transcription. Every other current or future ID uses the existing streaming
protocol; select `streamingTranscriptionModel(...)` for those models.

## Rotating credentials

The native provider settings accept an optional `apiKeyProvider` asynchronous
throwing closure. The provider resolves it for each authenticated request;
static keys and explicit custom authentication headers remain supported.
Supplier failures stop the request before it reaches the transport.
