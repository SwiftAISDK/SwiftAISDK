## Quick start

```swift
import SwiftAISDK

let vercel = try AIProviders.vercel()
let model = try vercel.languageModel("v0-1.5-md")
let result = try await model.generateText("Create a SwiftUI login form.")
print(result.text)
```

For the modular packages, use `import SwiftAI` and `import SwiftAIVercel`, then
`try AIProviders.vercel(configuration: VercelProviderSettings(...))`. The native factory
requires a configuration argument; `VercelProviderSettings()` reads `VERCEL_API_KEY`.

## v0 models

The provider calls the v0 Model API, an OpenAI-compatible Chat Completions endpoint at
`https://api.v0.dev/v1`. Model IDs include `v0-1.0-md`, `v0-1.5-md` and `v0-1.5-lg`.
`languageModel(_:)`, `chatModel(_:)` and calling the provider directly
(`try vercel("v0-1.5-md")`) return the same chat model. Text generation, streaming,
tools and the other chat features follow the shared OpenAI-compatible chat behavior;
see [Generate text](../../core/generate-text/) and [Stream text](../../core/stream-text/).
Options under `providerOptions["openaiCompatible"]` or `providerOptions["vercel"]`
(`user`, `reasoningEffort`, `textVerbosity`, `strictJsonSchema`) map like the generic
OpenAI-compatible provider, and other `vercel` keys are sent in the request body.

Only language models are available. Embedding, image, transcription, speech, video and
reranking factories throw an unsupported-model error.

## Settings

| Setting | Behavior |
| --- | --- |
| `apiKey` | Overrides `VERCEL_API_KEY`. The key is resolved when the provider is created. |
| `baseURL` | Replaces `https://api.v0.dev/v1`. |
| `headers` | Extra headers; an explicit `Authorization` header replaces the bearer key. |
| `queryParams` | Appended to every request URL. |
| `includeUsage` | Requests usage in streamed responses. |
| `supportsStructuredOutputs` | Sends JSON schema response formats instead of plain JSON mode. |
| `transformRequestBody` | Edits the JSON body before it is sent. |

The provider has no `apiKeyProvider` setting; create a new provider to rotate the key.
