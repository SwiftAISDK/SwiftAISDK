## Rotating API keys

`ReplicateProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

## Current request and response behavior

When image polling is aborted or exhausts its attempts, the adapter starts
a best-effort cancellation at the configured provider origin. It encodes the
prediction ID as one path segment, uses fresh provider credentials, excludes
per-call headers and the generation's abort signal, and rejects redirects.
Cancellation does not delay or replace the original generation error. Successful
predictions are not cancelled.
