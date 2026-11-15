## Quick start

```swift
import SwiftAISDK

// Reads GOOGLE_VERTEX_PROJECT, GOOGLE_VERTEX_LOCATION and GOOGLE_VERTEX_ACCESS_TOKEN.
let provider = try AIProviders.googleVertexXAI()
let model = try provider.languageModel("xai/grok-4.1-fast-reasoning")
let result = try await model.generateText("Summarize the plot of Hamlet in one line.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIGoogleVertex`, then call
`AIProviders.googleVertexXAI(project:location:configuration:)` with a
`GoogleVertexHostedProviderSettings`. The `configuration` argument is required.

## Authentication and endpoint

Grok models on Vertex use the OpenAI-compatible Chat Completions endpoint with an
OAuth bearer token. The token comes from `apiKey` in the settings, then
`GOOGLE_VERTEX_ACCESS_TOKEN`, then `GOOGLE_ACCESS_TOKEN`. Service-account
variables and Express Mode keys are not used.

The project (`project` argument or `GOOGLE_VERTEX_PROJECT`) is always required,
even when you set `baseURL`. The location comes from `location` or
`GOOGLE_VERTEX_LOCATION` and defaults to `global`. Requests go to
`https://aiplatform.googleapis.com/v1/projects/PROJECT/locations/global/endpoints/openapi/chat/completions`
for the global location.

```swift
let provider = try AIProviders.googleVertexXAI(
    project: "my-project",
    settings: ProviderSettings(apiKey: accessToken)
)
```

To refresh tokens before each request, use the `configuration:` factory and set
`GoogleVertexHostedProviderSettings.apiKeyProvider` to an async throwing closure.

## Behavior

- Only language models are available. Model IDs carry the `xai/` prefix.
- `reasoning_effort` is removed from every request body, including values passed
  through `extraBody`, so portable reasoning settings are not sent to this endpoint.
- Other request and response handling follows the
  [OpenAI-compatible provider](../openai-compatible/). For xAI's own API features
  (Responses, images, video, voice), use the [xAI provider](../xai/).
