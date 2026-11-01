## Rotating API keys

`LumaProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.
