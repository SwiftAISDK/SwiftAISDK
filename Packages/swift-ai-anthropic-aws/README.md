# SwiftAIAnthropicAWS

Swift-native port of `@ai-sdk/anthropic-aws`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.
Sources are owned by the canonical repository, with shared HTTP/SigV4 machinery
in core and Anthropic wire behavior in the Anthropic package.

Existing baselines and documented port gaps remain unchanged. See the canonical
provider guide and `Porting/map.json`.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/anthropic-aws.md) for authentication, options and supported surfaces.

Claude Platform on AWS supports Anthropic message threads through the canonical
`providerOptions.anthropic.thread` create/continue objects. AWS authentication and
workspace headers remain provider settings; keep full conversation history locally
for thread-expiry recovery. Bedrock InvokeModel is a separate hosting surface and
does not enable message threads.
