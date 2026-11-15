## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.huggingFace()
let model = try provider.languageModel("deepseek-ai/DeepSeek-V3-0324")
let result = try await model.generateText("Explain what a tokenizer does.")
print(result.text)
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIHuggingFace`
with the native factory `AIProviders.huggingFace(configuration: HuggingFaceProviderSettings())`.
The native factory requires the configuration argument; `HuggingFaceProviderSettings()`
reads `HUGGINGFACE_API_KEY` from the environment. Requests use bearer
authentication.

## Responses API

All language calls go to the Hugging Face router's Responses endpoint
(`https://router.huggingface.co/v1/responses`). `languageModel(_:)`,
`responsesModel(_:)`, `responses(_:)` and calling the provider directly return the
same model. Embedding and image models are not available.

Options under `providerOptions["huggingface"]`:

| Key | Values |
| --- | --- |
| `metadata` | String-to-string dictionary |
| `instructions` | System-style instructions string |
| `reasoningEffort` | Reasoning effort string, sent as `reasoning.effort` |
| `strictJsonSchema` | Boolean, strict mode for JSON Schema output (default `false`) |

```swift
let result = try await model.generateText(
    "Solve 17 × 23 step by step.",
    options: LanguageGenerationOptions(providerOptions: [
        "huggingface": ["reasoningEffort": "high"],
    ])
)
print(result.reasoning)
```

Invalid values fail before the request. `topK`, `seed`, `presencePenalty`,
`frequencyPenalty` and `stopSequences` are not supported and produce warnings.

## Tools, structured output and input

- Function tools and tool choice are supported. Tool choice `none` is sent as
  `tool_choice: "none"` while keeping the tool definitions. Provider-defined tools
  are dropped with a warning.
- Reasoning, function calls and MCP calls in the response are parsed into the
  standard result and stream parts.
- [Structured output](../../core/structured-output/) uses the Responses text
  format.
- Image inputs work as URLs or inline data (PNG, JPEG, GIF, WebP; a generic
  `image` type is resolved from the bytes). Provider file references are rejected.

## Streaming

If the stream ends before a completion event, the final part reports
`finishReason == "interrupted"`; text, reasoning, usage and metadata received so
far stay available. Malformed JSON and provider errors appear as error parts and
finish with `"error"`, keeping the provider's error type, code, status and
retryability. The response ID is in `providerMetadata["huggingface"]["responseId"]`.

## Rotating credentials

`HuggingFaceProviderSettings(apiKeyProvider:)` takes an async throwing closure that
is called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
