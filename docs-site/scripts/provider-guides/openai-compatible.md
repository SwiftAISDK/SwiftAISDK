## Quick start

```swift
import Foundation
import SwiftAISDK

let provider = try AIProviders.openAICompatible(
    name: "local",
    baseURL: "http://localhost:1234/v1",
    apiKey: ProcessInfo.processInfo.environment["LOCAL_API_KEY"]
)
let model = try provider.languageModel("local-model")
let result = try await model.generateText("Say hello.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIOpenAICompatible`, then
call `AIProviders.openAICompatible(configuration: OpenAICompatibleProviderSettings(name:baseURL:...))`.
The `configuration` argument is required, and the native factory does not throw.

## Connecting to a server

Use this provider for any server that implements the OpenAI Chat Completions,
Completions, Embeddings and Images endpoints, such as local inference servers and
proxies. No environment variable is read.

- `name` becomes the provider ID and the provider-options namespace. Pick a name
  of your own. On the umbrella factory, built-in provider IDs such as `mistral` or
  `groq` select that provider's special handling.
- `baseURL` is the API root; paths such as `/chat/completions` are appended.
  `queryParams` are added to every request.
- When `apiKey` is set, it is sent as `Authorization: Bearer ...`. Custom
  `headers` override it.
- `languageModel(_:)` and `chatModel(_:)` use Chat Completions.
  `completionModel(_:)`, `embeddingModel(_:)` and `imageModel(_:)` use the matching
  endpoints. Transcription, speech, video and reranking are unsupported.

## Settings

| Setting | Effect |
| --- | --- |
| `includeUsage` | Requests usage in streamed responses (`stream_options.include_usage`). |
| `supportsStructuredOutputs` | Sends JSON schemas as `json_schema` response formats. |
| `supportsMultiPartToolContent` | Sends rich tool-result content instead of a string. |
| `maxEmbeddingsPerCall` | Splits embedding batches. |
| `transformRequestBody` | Rewrites the JSON body before sending. |
| `transformRequestBodyWithWarnings` | Same, and can add warnings to the result. Runs after `transformRequestBody`. |

```swift
let provider = try AIProviders.openAICompatible(
    name: "proxy",
    baseURL: "https://proxy.example.com/v1",
    transformRequestBodyWithWarnings: { body, warnings in
        var body = body
        if body.removeValue(forKey: "seed") != nil {
            warnings.append(.init(type: "unsupported", feature: "seed", message: "The proxy ignores seeds."))
        }
        return body
    }
)
```

## Provider options

Options are read from `providerOptions[<name>]`. For a name with dashes, use
the camelCase key (`my-proxy` becomes `myProxy`); the raw key still works but
produces a deprecation warning. Options are merged into the request body.
`reasoningEffort` overrides portable `reasoning`; portable `none` becomes
`reasoning_effort: none`. An explicit `reasoningEffort: null` is sent as a null.

## Responses and content

- Reasoning (`reasoning_content` or thinking parts) comes before text and tool
  calls in `result.content`, both unary and streamed. Unknown content parts are
  ignored.
- Refusals are kept as text; a normal stop with a refusal finishes as
  `contentFilter`.
- User content accepts images, hosted video URLs (`.videoURL(...)`), inline text
  files and provider file references.
- Image results can be base64, URLs or both. URLs are downloaded through your
  transport into ordered `base64Images`; credentials are only sent to your API
  origin. `urls` keeps the original URLs.
- A stream that ends without a completion signal finishes with reason
  `interrupted`.
- Unknown usage fields, including nested prompt and completion details, stay
  available in raw usage.

## Rotating API keys

To rotate keys, set `OpenAICompatibleProviderSettings.apiKeyProvider` to an async
throwing closure and pass it to `AIProviders.openAICompatible(configuration:)`. It
runs before each authenticated request and for image downloads from your API
origin. Explicit authorization headers still take precedence.
