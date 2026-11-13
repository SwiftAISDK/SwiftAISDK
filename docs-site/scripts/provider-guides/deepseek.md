## Current reviewed behavior

The reviewed baseline is `@ai-sdk/deepseek` 3.0.86. The existing `languageModel`/`chatModel` factories retain Chat Completions. Opt into Responses and provider web search explicitly:

```swift
let model = provider.responses("deepseek-v4-pro")
let result = try await model.generate(.init(
    messages: [.user("Find the latest release notes.")],
    tools: ["search": DeepSeekTools.webSearch()],
    providerOptions: DeepSeekResponsesModelOptions(reasoningEffort: .high).providerOptions
))
```

Responses supports structured JSON, image URLs/inline images/provider references, ordered reasoning/tool replay, and unary or incremental SSE results. Reasoning `itemId`, full web-search call/action replay, response IDs, logprobs and exact server-tool usage survive in provider metadata. `thinking: .disabled` sends reasoning effort `none`; portable reasoning maps `medium` to `high` and `xhigh` to `max`, with compatibility warnings. `topLogprobs` and ASCII `userID` are validated before HTTP.

Strict tools, seed, topK, penalties and stop sequences produce unsupported warnings. Image URLs are limited to 8192 UTF-16 units, supported inline formats are JPEG/PNG/GIF/WebP, and `fileData` image mode is rejected for Responses. Incomplete/failed/abruptly-ended streams retain their terminal distinction. Model-level behavior is mock-tested; no live-service guarantee is implied.

## Current protocol for future model IDs

Unknown model IDs inherit the V4-or-newer protocol, including thinking defaults and required `reasoning_content` on assistant turns. Known `deepseek-chat`, `deepseek-reasoner` and V1–V3 version IDs keep the legacy protocol, including provider-prefixed forms such as `provider/deepseek-v2.5`.

## Rotating credentials

The native `DeepSeekProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.


## Chat Completions portable reasoning

Chat Completions portable effort maps to DeepSeek's `low`, `high`, or `max` settings. `medium` now maps to `low` and `xhigh` to `high`, with compatibility warnings in generation and stream-start metadata. Explicit provider effort retains its existing native option validation and precedence; portable `none` still disables thinking.
## Chat Completions tool replay and Azure strict options

Tool arguments retain valid serialized JSON and JSON-quote malformed raw text.
Native DeepSeek Chat Completions strict tools still require the beta endpoint and consistent
strict mode. Azure-hosted configurations have unknown strict-tool capability;
they forward each tool's explicit true/false/omitted choice without applying the
native beta-only policy.
