## Rotating API keys

`AssemblyAIProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

## Current request and response behavior

HTTP upload, submit and polling failures accept AssemblyAI's flat
`{"error":"message"}` response as well as the legacy nested error object.
The native API-call error preserves the status and response headers. Unrecognized
bodies remain available through the existing native raw-body error fallback.
