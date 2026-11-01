## Rotating API keys

`OpenResponsesProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

The optional `headersProvider` asynchronous closure also supplies fresh default
headers for every generated or streamed response. Request headers take precedence.
