## Perplexity 5 routing

`languageModel(...)` and the callable provider use `/v1/agent`.
Choose `chatModel(...)` or `sonarModel(...)` for legacy Sonar Chat Completions.
`embeddingModel(...)` uses `/v1/embeddings`.

## Native decisions

```swift
let perplexity = try AIProviders.perplexity()
let result = try await AI.experimentalDecide(
    model: try perplexity.decisionModel("pplx-judge"),
    state: .text("The package arrived cracked."),
    questions: ["damaged": .boolean(criteria: ["true": "Package is damaged"])]
)
```

The `/v1/decisions` endpoint accepts 1–128 named Choice, Score and Boolean
questions. Choice supports 1–255 options; Score requires 1–10 non-null levels.
Instructions may be omitted when the rubric defines the judgment. Box is
unsupported. State preserves ordered text/JSON and up to eight inline PNG,
JPEG or WebP images, including images nested in JSON. The facade resolves URLs
before adapter execution.

Answers retain full precision without rounding allowance. Confidence and score
legends live under `providerMetadata.perplexity`; response metadata keeps
`x-request-id`, resolved model, headers and raw body. `maxOutputTokens`,
`reasoning` and Perplexity provider options produce unsupported warnings.
