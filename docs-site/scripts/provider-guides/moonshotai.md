## Structured output model support

Every Moonshot model ID, including legacy `moonshot-v1-*` and custom/future IDs, forwards JSON Schema structured output. Capability detection no longer depends on the `kimi-k` family prefix.

Generated content follows Moonshot's order: reasoning, function tool calls, then
text; the `text` and `toolCalls` convenience fields remain available.

## Kimi K3.1 context caching

`kimi-k3.1-pro` and `kimi-k3.1-pro-highspeed` share Kimi K3's request and history behavior. They always reason and omit the `thinking` request field, including when preserved history is selected. Kimi K2.6 uses `thinking.keep = "all"` for preserved history.

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

## Rotating credentials

The native `MoonshotAIProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.


## Portable reasoning effort

Kimi K3 maps portable reasoning to `low`, `high`, or `max`, preferring the closest lower supported effort. `none`, `minimal` and `medium` map to `low`; `xhigh` maps to `high`, with compatibility warnings. Explicit canonical `reasoningEffort` provider options retain precedence. Kimi K2.7 cannot disable thinking: portable `none` keeps the provider default and emits a compatibility warning, while an explicit disabled-thinking option remains unsupported. Unknown model IDs send portable `none` as disabled thinking, allowing the service to decide support.

Typed `thinking.budgetTokens` is deprecated and omitted. The native raw `extraBody` escape hatch remains available for service-specific controls. Model-specific reasoning restrictions apply to the documented IDs; unrecognized names retain the unknown-model policy.
