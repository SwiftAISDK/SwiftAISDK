## Structured output model support

Every Moonshot model ID, including legacy `moonshot-v1-*` and custom/future IDs, forwards JSON Schema structured output. Capability detection no longer depends on the `kimi-k` family prefix.

Generated content follows Moonshot's order: reasoning, function tool calls, then
text; the `text` and `toolCalls` convenience fields remain available.

## Kimi K3.1 context caching

`kimi-k3.1-pro` and `kimi-k3.1-pro-highspeed` share Kimi K3's reasoning-history
support. Use `reasoningHistory: "preserved"` to send `thinking.keep = "all"`.

```swift
let provider = try AIProviders.moonshotAI()
let model = try provider.languageModel("kimi-k3.1-pro")
let result = try await model.generate(LanguageModelRequest(
    messages: [.user("Summarize the supplied context")],
    providerOptions: ["moonshotai": [
        "promptCacheOptions": ["ttl": "1h"],
        "reasoningHistory": "preserved"
    ]]
))
```

`promptCacheOptions` accepts optional `mode: "implicit"` and `ttl: "5m"` or
`"1h"`. An empty object sends the default implicit mode; omitting the option
omits the cache object. Invalid values fail before network I/O.

`usage.inputTokensCacheWrite` reports cache writes, and `inputTokensNoCache`
excludes cache reads and writes. The `msh-usage-cache-write-tokens-5m` and `-1h`
response headers populate `providerMetadata["moonshotai"]["cacheWriteTokens"]`
with `ttl5m` and `ttl1h`; malformed counts are ignored. Both unary and streaming
calls retain these fields.

MFJS tool and response JSON schemas retain `type: "object"` at the root. A root
`anyOf` or `oneOf` containing only objects is accepted, including one-hop local
`$defs` and `definitions` references. Non-object, nullable-object and empty root
unions fail before sending. Nested unions retain the provider's type-placement
rules.
