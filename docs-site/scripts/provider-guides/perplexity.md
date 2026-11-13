## Current reviewed behavior

The reviewed baseline is `@ai-sdk/perplexity` 5.0.34. Native decisions accept `PerplexityDecisionModelOptions(mode: .webGrounding, maxStaleness: 0)`. `mode` sends `web_grounding`; maximum staleness is a nonnegative integer representing fetched-page age in seconds, including zero.

Results expose `searchResults`, `fetchedResults` and exact `toolCalls` invocation counts under `providerMetadata.perplexity`. Missing invocation counts remain null and reported zeros are preserved. HTTP failures retain grounding-count headers and retryability. Unknown decision options still produce unsupported warnings; invalid grounding options fail before HTTP.

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

## Rotating credentials

The native `PerplexityProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.


## Search query metadata

Agent responses expose `providerMetadata.perplexity.searchQueries` in first-seen order, without duplicates. Generation collects all search-result items; streaming combines reasoning search-query events, completed output items and terminal response output. Fetch URL events do not become search queries. When no query was reported, the value is JSON null. Invalid query arrays fail response validation.

Portable `reasoning: "none"` maps to the lowest supported effort, `minimal`, with a compatibility warning. Explicit native reasoning options keep their precedence.

## Current request and response behavior

Use tool choice `none` to disable both explicit tools and tools enabled by
an Agent preset. The adapter omits all tool definitions and forces
`max_tool_calls: 0`, even when provider options supplied another limit. Historical
tool calls/results stay in the prompt. Disabled provider tools do not produce
unsupported-tool warnings or leak tool credentials into the request.
