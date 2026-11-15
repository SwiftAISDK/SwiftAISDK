## Quick start

```swift
import SwiftAISDK

// Reads GOOGLE_VERTEX_PROJECT, GOOGLE_VERTEX_LOCATION and GOOGLE_VERTEX_ACCESS_TOKEN.
let provider = try AIProviders.googleVertexAnthropic()
let model = try provider.languageModel("claude-sonnet-4@20250514")
let result = try await model.generateText("Explain Swift actors in two sentences.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIGoogleVertex`, then call
`AIProviders.googleVertexAnthropic(project:location:configuration:)` with a
`GoogleVertexHostedProviderSettings`. The `configuration` argument is required. The
same overload is also available from `import SwiftAISDK`.

## Authentication and endpoint

This adapter sends an OAuth bearer token. It reads `apiKey` from the settings, then
`GOOGLE_VERTEX_ACCESS_TOKEN`, then `GOOGLE_ACCESS_TOKEN`. Service-account
environment variables and Express Mode keys are not used here. Get a token
yourself, for example from `gcloud auth print-access-token` or your own token
service.

The project comes from the `project` argument or `GOOGLE_VERTEX_PROJECT`. The
location comes from `location` or `GOOGLE_VERTEX_LOCATION` and defaults to
`global`. Requests go to
`.../projects/PROJECT/locations/LOCATION/publishers/anthropic/models/MODEL:rawPredict`
with `anthropic_version: vertex-2023-10-16`; the model ID is in the URL, not the
body. Setting `baseURL` replaces the computed URL.

To refresh tokens without recreating the provider, use the `configuration:` factory
and set `GoogleVertexHostedProviderSettings.apiKeyProvider` to an async throwing
closure that returns the current token. It runs before each request.

## Provider options

Claude options use the shared [Anthropic](../anthropic/) option set. They are read
from `providerOptions["anthropic"]`, and then from `googleVertex` or `vertex`
(whichever comes first), so thinking, cache control, citations and beta headers work
as they do with Anthropic.

### Request labels

Set `providerOptions["vertex"]["labels"]` to an object with string values to attach
billing labels:

```swift
let result = try await model.generateText(
    "Hello",
    options: LanguageGenerationOptions(
        providerOptions: ["vertex": ["labels": ["team": "ios"]]]
    )
)
```

Labels are sent as base64 UTF-8 JSON in the `x-vertex-ai-labels` header and are
not added to the request body. An explicit `x-vertex-ai-labels` header of any
casing wins. Invalid labels throw before any network call.

## Structured output

With `AIProviders.googleVertexAnthropic(project:location:configuration:)`, automatic
native JSON output is off by default. Turn it on with
`supportsNativeStructuredOutput: true` on `GoogleVertexHostedProviderSettings`. It
then applies only to Claude 4.5 and later, and only when your Google Cloud
organization policy allows `structured_outputs`. Strict tool inputs are always
off on this path.

Shared Anthropic rules still apply. `structuredOutputMode: "outputFormat"` requests
native output explicitly, and models that reject forced JSON tools fall back to a
native schema. The umbrella `settings:` factory does not set this hosting default.
It follows the model's own structured-output capability.

## Provider tools

`GoogleVertexAnthropicTools` exposes the Claude tools that Vertex supports: bash,
computer, text editor, web search and tool search (regex and BM25).

```swift
let result = try await model.generateText(
    "Find the latest Swift release.",
    tools: LanguageToolOptions(rawTools: [
        "search": GoogleVertexAnthropicTools.webSearch_20250305(maxUses: 2),
    ])
)
```
