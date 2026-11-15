## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.baseten()
let model = try provider.languageModel("deepseek-ai/DeepSeek-V3-0324")
let result = try await model.generateText("Explain Baseten Model APIs in one sentence.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIBaseten`, then call
`AIProviders.baseten(configuration: BasetenProviderSettings(...))`; the native
factory requires the configuration argument.

Without a `modelURL`, chat requests go to the Baseten Model APIs at
`https://inference.baseten.co/v1`. Responses include streamed usage, and JSON
Schema structured output is sent natively. `chatModel(...)` is an alias for
`languageModel(...)`.

## Dedicated deployments

Set `modelURL` to call your own deployment instead of Model APIs:

```swift
let provider = try AIProviders.baseten(settings: ProviderSettings(
    modelURL: "https://model-abc.api.baseten.co/environments/production/sync/v1"
))
let model = try provider.languageModel()
```

- Chat requires a `/sync/v1` URL. `/predict` URLs are rejected.
- `languageModel()` and `chatModel()` without an ID use the deployment's default
  model.

## Embeddings

Embeddings are only available for dedicated deployments and require a `/sync` or
`/sync/v1` `modelURL` (`/v1` is appended to `/sync`):

```swift
let provider = try AIProviders.baseten(settings: ProviderSettings(
    modelURL: "https://model-abc.api.baseten.co/environments/production/sync"
))
let embedder = try provider.embeddingModel()
let result = try await embedder.embedMany(["first", "second"])
```

Inputs are sent in batches of up to 128 values. Calling `embeddingModel` without a
suitable `modelURL` throws `AIError.invalidArgument`.

## Provider options

Options under `providerOptions["baseten"]` (or `providerOptions["openaiCompatible"]`)
follow the [OpenAI-compatible](../openai-compatible/) chat options, for example
`reasoningEffort`. Portable `reasoning` is mapped to `reasoning_effort`.

For the Model APIs model `deepseek-ai/DeepSeek-V4-Pro-0813`, JSON output combined
with reasoning (the default) is not constrained by the server: the adapter omits
`response_format`, injects JSON instructions into a system message and returns a
compatibility warning. Set `reasoning` to `"none"` to keep native JSON mode.

## Rotating credentials

`BasetenProviderSettings` accepts an `apiKeyProvider` async throwing closure that
is called before each authenticated request. A supplier error stops the request
before it is sent.
