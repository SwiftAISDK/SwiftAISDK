## Quick start

```swift
import SwiftAISDK

let parallel = AIProviders.parallel()
let result = try await AI.experimentalDecide(
    model: try parallel.decisionModel("fast"),
    state: .parts([.json(["company": "Parallel", "website": "https://parallel.ai"])]),
    questions: [
        "hasSearch": .boolean(instructions: "Does it offer web search?"),
        "availability": .choice(
            instructions: "Is the API available?",
            criteria: ["available": "Publicly available", "unknown": "Insufficient evidence"]
        ),
        "fit": .score(instructions: "How well does it fit?", criteria: ["No fit", "Partial fit", "Full fit"])
    ],
    providerOptions: ParallelDecisionModelOptions(includeExcerpts: false).providerOptions
)
let citations = result.providerMetadata["parallel"]?["citations"]
```

For the modular packages, use `import SwiftAI` and `import SwiftAIParallel`, then
`AIProviders.parallel(configuration: ParallelProviderSettings(...))` or
`createParallel(configuration:)`. Both default to `ParallelProviderSettings()` and do not
throw; `parallel` is a default provider instance.

Parallel answers decision questions by researching the web. It has no text, image,
embedding, video or audio models and no streaming.

## Models and endpoint

The model ID is sent as the service `mode`. `fast` is the known mode; any other nonempty
ID is forwarded, so new modes work without an SDK update. Requests go to
`https://api.parallel.ai/v1/decisions`; `baseURL` replaces the part before `/decisions`.

`parallelModelCatalog`, `getParallelDecisionModelEntry(_:)` and `parallelProviderOptions`
describe what each mode supports. They do not change request validation.

## Questions and state

- 1–100 questions whose names use only ASCII letters, digits, underscores or hyphens.
- Boolean, Choice (2–255 options) and Score (2–10 levels) questions. Box questions and
  file evidence are rejected before the request.
- State may contain ordered text and JSON parts. A single part is sent as-is; zero or
  several parts are sent as a JSON array.

`ParallelDecisionModelOptions(includeExcerpts:)` controls evidence excerpts in
citations; omit it to keep the service default (on). Other provider options,
`maxOutputTokens` and `reasoning` produce warnings.

## Results

Answers keep full numeric precision. `providerMetadata["parallel"]` contains
`citations` (shared across the request, not per answer), `confidence`, `legend`,
`decisionId` and `mode`. Decode it with the Codable `ParallelDecisionProviderMetadata`
for typed access. Response metadata includes the decision ID, the requested model ID,
headers and the raw JSON body.

The provider returns refusals alongside other answers; `AI.experimentalDecide` throws
`AIDecisionRefusalError` when any question is refused. HTTP errors keep the status,
retry headers and body in `AIAPICallError`. See [Decisions](../../core/decide/).

## Authentication

Requests send the key as `x-api-key`. The key is read when a request is made: from
`apiKey`, then `PARALLEL_API_KEY` (or the `environment` map you pass). `apiKeyProvider`
accepts an async throwing closure that supplies a fresh key before each request. Call
headers override provider headers, and `abortSignal` cancels the request.
