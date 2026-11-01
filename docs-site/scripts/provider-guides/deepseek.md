## Current protocol for future model IDs

Unknown model IDs inherit the V4-or-newer protocol, including thinking defaults and required `reasoning_content` on assistant turns. Known `deepseek-chat`, `deepseek-reasoner` and V1–V3 version IDs keep the legacy protocol, including provider-prefixed forms such as `provider/deepseek-v2.5`.

## Rotating credentials

The native `DeepSeekProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.


## Portable reasoning

Portable effort maps to DeepSeek's `low`, `high`, or `max` settings. `medium` now maps to `low` and `xhigh` to `high`, with compatibility warnings in generation and stream-start metadata. Explicit provider effort retains its existing native option validation and precedence; portable `none` still disables thinking.
