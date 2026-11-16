## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.cohere()
let model = try provider.languageModel("command-a-03-2025")
let result = try await model.generateText("Write a one-line product tagline.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAICohere`, then call
`AIProviders.cohere(configuration: CohereProviderSettings(...))`; the native
factory requires the configuration argument.

Requests use Cohere's v2 API at `https://api.cohere.com/v2` (`/chat`, `/embed`,
`/rerank`). `chatModel(...)` is an alias for `languageModel(...)`.

## Reasoning

```swift
let reasoner = try provider.languageModel("command-a-reasoning-08-2025")
let result = try await reasoner.generateText(
    "Plan a database migration.",
    options: LanguageGenerationOptions(
        providerOptions: ["cohere": ["thinking": ["type": "enabled", "tokenBudget": 2_000]]]
    )
)
print(result.reasoning)
```

`providerOptions["cohere"]["thinking"]` accepts `type` (`"enabled"` or
`"disabled"`) and `tokenBudget`, and takes precedence over portable `reasoning`.
Portable `reasoning` maps to a token budget out of 32,768 tokens; `"none"`
disables thinking. If a level cannot be mapped to a budget, thinking is enabled
without one and an unsupported-reasoning warning is returned.

## Documents and citations

Non-image file parts are sent as Cohere documents, decoded from `Data` as UTF-8,
with the file name as the title; the media type is not sent and document order is
preserved. Images are sent inline as data URLs (a partial `image` or `image/*`
type is resolved from the bytes), with an optional
`providerMetadata: ["cohere": ["detail": "low" | "high" | "auto"]]` on the image
part. File URLs must be downloaded first.

Responses include document citations as sources in generated and streamed
results. Citations that refer only to tool output stay in the raw response.

Usage reports cached input tokens separately; billed units remain in the raw usage
and are not used as token counts.

## Embeddings

```swift
let embedder = try provider.embeddingModel("embed-v4.0")
let result = try await embedder.embedMany(
    ["first document", "second document"],
    providerOptions: ["cohere": ["inputType": "search_document", "outputDimension": 1024]]
)
```

- `inputType`: `search_document`, `search_query` (default), `classification` or
  `clustering`.
- `embeddingType`: `float` (default), `int8`, `uint8`, `binary` or `ubinary`.
  Binary types return packed bytes as numbers.
- `outputDimension`: 256, 512, 768, 1024, 1536 or 2048; overrides the shared
  `dimensions` argument.
- `truncate`: `NONE`, `START` or `END`.

Up to 96 texts are sent per request. See [Embeddings](../../core/embeddings/).

## Reranking

```swift
let reranker = try provider.rerankingModel("rerank-v3.5")
let ranked = try await reranker.rerank(
    query: "Which document explains provider options?",
    documents: ["Provider options carry provider-specific settings.", "Swift is a language."],
    topK: 1
)
```

`topK` is sent as `top_n`. Options: `maxTokensPerDoc` and `priority`. Object
documents are converted to JSON strings with a compatibility warning. See
[Rerank](../../core/rerank/).

## Rotating credentials

`CohereProviderSettings` accepts an `apiKeyProvider` async throwing closure that
is called before each authenticated request. A supplier error stops the request
before it is sent.
