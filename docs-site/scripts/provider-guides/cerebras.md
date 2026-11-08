## Rotating API keys

`CerebrasProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

## Current request and response behavior

Set `providerOptions.cerebras.queueThreshold` to an integer from 50 through
20000 to request the maximum flex/auto queue time in milliseconds. The adapter
sends `queue_threshold` as a header, overriding a case-insensitive per-call header,
and omits the option from the JSON body. Returned `service_tier` is available as
`providerMetadata.cerebras.serviceTier`, including the final stream metadata.

Only `queueThreshold` is validated on the dynamic `cerebras` option path; other
values retain upstream passthrough, including an explicit `reasoningEffort: null`.
Unary and streaming responses retain refusal text, with client tool-call finish
priority and ordered text/refusal delivery. Low-level request metadata exposes
the actual configured endpoint; high-level results sanitize it to an origin.
