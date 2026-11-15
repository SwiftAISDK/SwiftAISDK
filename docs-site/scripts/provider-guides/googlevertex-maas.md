## Quick start

```swift
import SwiftAISDK

// Reads GOOGLE_VERTEX_PROJECT, GOOGLE_VERTEX_LOCATION and GOOGLE_VERTEX_ACCESS_TOKEN.
let provider = try AIProviders.googleVertexMaaS()
let model = try provider.languageModel("meta/llama-4-maverick-17b-128e-instruct-maas")
let result = try await model.generateText("List three uses for Swift on the server.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIGoogleVertex`, then call
`AIProviders.googleVertexMaaS(project:location:configuration:)` with a
`GoogleVertexHostedProviderSettings`. The `configuration` argument is required.

## Authentication and endpoint

Model Garden MaaS models (open models such as Llama, served as managed APIs) use
Vertex's OpenAI-compatible endpoint with an OAuth bearer token. The token comes from
`apiKey` in the settings, then `GOOGLE_VERTEX_ACCESS_TOKEN`, then
`GOOGLE_ACCESS_TOKEN`. Service-account variables and Express Mode keys are not
used.

The project comes from the `project` argument or `GOOGLE_VERTEX_PROJECT`, and is
required unless you set `baseURL`. The location comes from `location` or
`GOOGLE_VERTEX_LOCATION` and defaults to `global`. Requests go to
`https://HOST/v1/projects/PROJECT/locations/LOCATION/endpoints/openapi/chat/completions`.
For `global` the host is `aiplatform.googleapis.com`; for a region it is
`LOCATION-aiplatform.googleapis.com`.

```swift
let provider = try AIProviders.googleVertexMaaS(
    project: "my-project",
    location: "us-central1",
    settings: ProviderSettings(apiKey: accessToken)
)
```

To refresh tokens before each request, use the `configuration:` factory and set
`GoogleVertexHostedProviderSettings.apiKeyProvider` to an async throwing closure.

## Models

- `languageModel(_:)` and `chatModel(_:)` use Chat Completions. Model IDs include the
  publisher prefix, for example `meta/llama-3.1-405b-instruct-maas`.
- `completionModel(_:)`, `embeddingModel(_:)` and `imageModel(_:)` use the matching
  OpenAI-compatible routes.

`meta/llama-4-maverick-17b-128e-instruct-maas` and
`meta/llama-4-scout-17b-16e-instruct-maas` default to `max_tokens: 8192`. Setting
`maxOutputTokens` overrides this. The default is applied after your
`transformRequestBody`.

Request and response handling, including `includeUsage`,
`supportsStructuredOutputs` and `transformRequestBody`, follows the
[OpenAI-compatible provider](../openai-compatible/). Image URLs in responses are
downloaded without your Google Cloud token or provider headers.
