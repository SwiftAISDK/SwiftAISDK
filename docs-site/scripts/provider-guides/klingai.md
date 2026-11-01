## Rotating API keys

`KlingAIProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

Returned keys are trimmed. Blank callback results follow the existing environment
or legacy key-pair fallback; legacy JWTs are generated for each request.
