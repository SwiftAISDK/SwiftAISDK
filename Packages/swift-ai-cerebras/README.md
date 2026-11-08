# SwiftAICerebras

Swift-native port of `@ai-sdk/cerebras`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.
## Behavior notes

`providerOptions.cerebras.queueThreshold` accepts an integer from 50 to 20,000 and sets the `queue_threshold` header, overriding caller header casing. Other dynamic `cerebras` options retain upstream pass-through behavior, including future service tiers. Returned `service_tier` is exposed as `providerMetadata.cerebras.serviceTier`; streams retain the last non-null effective tier.

Model request metadata includes the actual configured request URL in both unary and streaming calls. Refusal strings are surfaced as text and turn a stopped response into `content-filter`; ordinary tool-call and structured-output finish handling is retained.
