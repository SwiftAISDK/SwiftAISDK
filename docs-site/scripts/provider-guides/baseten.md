## Rotating API keys

`BasetenProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

## Current request and response behavior

For the serverless `deepseek-ai/DeepSeek-V4-Pro-0813` model, requesting JSON
while reasoning is enabled (including its default) injects a new system JSON
instruction and omits `response_format`. A compatibility warning explains that
the server does not constrain this output. Explicit reasoning `none` preserves
JSON mode; dedicated `modelURL` deployments and other models retain their prior
request behavior.

`providerOptions.baseten` follows the compatible option path. Portable reasoning
and either `reasoningEffort` or raw `reasoning_effort` overrides are resolved
before the fallback, including `none` in both generation and streaming.
