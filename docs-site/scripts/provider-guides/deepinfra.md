## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.deepInfra()
let model = try provider.languageModel("meta-llama/Llama-3.3-70B-Instruct")
let result = try await model.generateText("Summarize the plot of Hamlet in two sentences.")
print(result.text)
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIDeepInfra`
with the native factory `AIProviders.deepInfra(configuration: DeepInfraProviderSettings())`.
The native factory requires the configuration argument; `DeepInfraProviderSettings()`
reads `DEEPINFRA_API_KEY` from the environment.

## Models and routes

| Factory | Endpoint |
| --- | --- |
| `languageModel(_:)`, `chatModel(_:)` | `/v1/openai/chat/completions` |
| `completionModel(_:)` | `/v1/openai/completions` |
| `embeddingModel(_:)` | `/v1/openai/embeddings` |
| `imageModel(_:)` | `/v1/inference/{model}`, or `/v1/openai/images/edits` when input images are supplied |

A custom `baseURL` may end in `/v1`, `/v1/openai` or `/v1/inference`; the SDK
derives the other routes from it.

```swift
let embedder = try provider.embeddingModel("BAAI/bge-base-en-v1.5")
let vectors = try await embedder.embedMany(["alpha", "beta"])
```

## Chat behavior

- JSON Schema structured output is sent natively for every DeepInfra chat model,
  so [structured output](../../core/structured-output/) works without extra settings.
- For models that report reasoning tokens outside the completion count (for
  example Gemma and Gemini models), usage is corrected so `outputTokens` includes
  reasoning and `outputReasoningTokens` is reported separately.
- Extra request fields go under `providerOptions["deepinfra"]` and are passed
  through to the request body.

## Images

```swift
let image = try provider.imageModel("black-forest-labs/FLUX-1-schnell")
let result = try await image.generateImage(
    "A lighthouse at dusk, watercolor",
    size: "1024x768",
    seed: 42
)
let base64 = result.base64Images.first
```

- One image per call. `count` greater than 1 fails before the request.
- `size` is split into `width` and `height`; `aspectRatio` and `seed` are forwarded.
- Passing `files` (and optionally `mask`) switches to the OpenAI-compatible
  multipart edit endpoint. Models such as `black-forest-labs/FLUX.1-Kontext-dev`,
  FLUX 1.x and Stable Diffusion 3.5 report file and mask support; other models
  report unknown (`nil`).
- `providerOptions["deepinfra"]` fields are merged into the generation body or
  added as edit form fields.
- Results are returned as base64 data.

## Rotating credentials

`DeepInfraProviderSettings(apiKeyProvider:)` takes an async throwing closure that
is called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
