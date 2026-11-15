## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.deepSeek()
let model = try provider.languageModel("deepseek-v4-flash")
let result = try await model.generateText("Explain the CAP theorem in one paragraph.")
print(result.text)
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIDeepSeek`
with the native factory `AIProviders.deepSeek(configuration: DeepSeekProviderSettings())`.
The native factory requires the configuration argument; `DeepSeekProviderSettings()`
reads `DEEPSEEK_API_KEY` from the environment. The Responses API and rotating
credentials are available only on the native provider.

`languageModel(_:)` and `chatModel(_:)` use Chat Completions (`/chat/completions`).

## Model protocols

Model IDs are classified by name:

- `deepseek-chat`, `deepseek-reasoner` and V1–V3 IDs (including prefixed forms
  such as `provider/deepseek-v2.5`) use the legacy protocol.
- Every other ID, including future ones, uses the V4 protocol: thinking is on by
  default and assistant turns must carry their `reasoning_content`, which the SDK
  replays from message history.

While thinking is enabled, `temperature` and `topP` are dropped with a warning.
`frequencyPenalty` and `presencePenalty` are omitted with a deprecation warning;
`topK` and `seed` are unsupported.

## Thinking and provider options

Chat models read `providerOptions["deepseek"]`:

```swift
let result = try await model.generateText(
    "Prove that there are infinitely many primes.",
    options: LanguageGenerationOptions(providerOptions: [
        "deepseek": [
            "thinking": ["type": "enabled"],
            "reasoningEffort": "high",
        ],
    ])
)
print(result.reasoning)
```

| Key | Values |
| --- | --- |
| `thinking` | `["type": "enabled"]` or `["type": "disabled"]`; `adaptive` is sent as `enabled` with a warning |
| `reasoningEffort` | `low`, `high`, `max`; `medium` becomes `high` and `xhigh` becomes `max`, with a warning |
| `logprobs`, `topLogprobs` | Boolean; integer 0–20 (also enables `logprobs`) |
| `userId` | Letters, digits, `_` and `-`, at most 512 characters |
| `strictJsonSchema` | Boolean, used when JSON Schema output is enabled |

Invalid values fail before the request. The portable `reasoning` option also works:
`none` disables thinking and other levels map to the nearest DeepSeek effort with
a compatibility warning. Explicit provider options take precedence.

Usage reports DeepSeek prompt cache hits as cached input tokens, and cache
hit/miss counts appear in provider metadata.

## Structured output and tools

JSON output with a schema is implemented by adding the schema to the system
message and requesting `json_object`, with a compatibility warning. Set
`supportsStructuredOutputs: true` in the settings to send native `json_schema`
instead.

Function tools work in generation and streaming. Strict tools
(`"strict": true`) and assistant prefix completion require a beta base URL ending
in `/beta`, for example `DeepSeekProviderSettings(baseURL: "https://api.deepseek.com/beta")`;
otherwise the request fails before it is sent.

## Images and files

Vision models such as `deepseek-v4-flash-vision-exp` accept image URLs (up to 8192
characters), inline JPEG, PNG, GIF and WebP data, and uploaded file references.
Other content types are dropped with an unsupported warning.

`files()` uploads to the DeepSeek Files API with purpose `user_data`. Set an
expiry with `providerOptions["deepseek"]["expiresAfter"]` (3600–2592000 seconds):

```swift
let uploaded = try await AI.uploadFile(
    client: provider.files(),
    request: FileUploadRequest(
        data: imageData,
        mediaType: "image/png",
        filename: "chart.png",
        providerOptions: ["deepseek": ["expiresAfter": 86_400]]
    )
)
print(uploaded.providerReference)
```

A custom `purpose` is ignored with a warning. See [Files](../../core/files/).

## Responses API and web search

The native provider also exposes DeepSeek's Responses API through
`responses(_:)`, with the provider-defined web search tool:

```swift
import SwiftAI
import SwiftAIDeepSeek

let deepseek = try AIProviders.deepSeek(configuration: DeepSeekProviderSettings())
let model = deepseek.responses("deepseek-v4-pro")
let result = try await model.generate(LanguageModelRequest(
    messages: [.user("Find the latest release notes.")],
    tools: ["search": DeepSeekTools.webSearch()],
    providerOptions: DeepSeekResponsesModelOptions(reasoningEffort: .high).providerOptions
))
print(result.text)
```

`DeepSeekResponsesModelOptions` takes `thinking` (`.enabled`, `.disabled`),
`reasoningEffort` (`.low`, `.high`, `.max`), `topLogprobs` and `userID`.
`thinking: .disabled` sends effort `none`. Portable reasoning maps `minimal` to
`low`, `medium` to `high` and `xhigh` to `max`.

Responses supports structured JSON, image URLs, inline images and provider file
references (not `fileData` image mode), reasoning and tool replay, and streaming.
Reasoning item IDs, web search calls, response IDs, logprobs and server-tool usage
are kept in provider metadata. Strict tools, `seed`, `topK`, penalties and stop
sequences produce unsupported warnings. Forcing the web search tool through tool
choice is ignored with a warning.

## Rotating credentials

`DeepSeekProviderSettings(apiKeyProvider:)` takes an async throwing closure that
is called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
