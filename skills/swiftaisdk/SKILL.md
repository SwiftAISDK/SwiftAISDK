---
name: swiftaisdk
description: Build Swift apps and packages with SwiftAISDK, the SwiftPM port of the Vercel AI SDK. Use when adding SwiftAISDK to Package.swift, choosing a provider with AIProviders.*() and languageModel(_:), calling generateText or streamText, producing typed values with Output, defining AITool tools with LanguageToolOptions, configuring provider API keys, or debugging SwiftAISDK errors.
---

# SwiftAISDK

SwiftAISDK is a SwiftPM library that ports the provider-facing surface of the
Vercel AI SDK to Swift. One call shape works across OpenAI, Anthropic, Google,
Gateway and roughly fifty other providers.

## Read the docs before writing code

The API surface is large and changes weekly. Do not rely on memory or on the
TypeScript AI SDK: Swift names, labels and result types differ. Before using a
feature, fetch the matching Markdown page.

- Index of every page: https://swiftaisdk.github.io/SwiftAISDK/llms.txt
- Every page is also served as Markdown: replace the trailing slash of a page
  URL with `.md`, e.g. `https://swiftaisdk.github.io/SwiftAISDK/core/tools.md`.
- Useful pages: `/getting-started/install.md`, `/getting-started/quickstart.md`,
  `/core/generate-text.md`, `/core/stream-text.md`, `/core/structured-output.md`,
  `/core/tools.md`, `/core/error-handling.md`, `/providers.md` (provider matrix)
  and `/providers/<provider>.md` (e.g. `/providers/anthropic.md`).
- Exact public symbols: `/reference/generated/public-symbols.md`.

If a symbol is not in the docs or the symbol reference, it does not exist.
Check before inventing a parameter.

## Install

Add the umbrella package and product to `Package.swift`. Look up the latest
release tag at https://github.com/SwiftAISDK/SwiftAISDK/releases and use it as
the lower bound:

```swift
dependencies: [
    .package(url: "https://github.com/SwiftAISDK/SwiftAISDK.git", from: "<latest-version>"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SwiftAISDK", package: "SwiftAISDK"),
        ]
    ),
]
```

Then `import SwiftAISDK`.

Version pinning:

- Applications: `exact:` pins the umbrella, but only a committed
  `Package.resolved` freezes the full core/provider graph. Commit it.
- Reusable libraries: express a compatible range (`from:`), not `exact:`.
- Never depend on the moving `main` branch in production.
- Smaller dependency graphs can use the independent modular packages
  (`swift-ai-core` with product `SwiftAI`, plus e.g. `swift-ai-openai` with
  `SwiftAIOpenAI`). Their native factories take `configuration:` with
  provider-specific settings such as `OpenAIProviderSettings`. See
  `/getting-started/install.md` before choosing modular packages; do not mix
  2.x types with modular values.

## Providers and models

Create a provider with an `AIProviders` factory, then resolve a model by ID:

```swift
import SwiftAISDK

let provider = try AIProviders.openAI()
let model = try provider.languageModel("gpt-6.1-sol")
```

Switch providers by changing only the factory and model ID:

```swift
let provider = try AIProviders.anthropic()
let model = try provider.languageModel("claude-opus-5-5")
```

Factory names follow the provider matrix at `/providers.md`, e.g.
`AIProviders.google`, `AIProviders.gateway`, `AIProviders.azure`,
`AIProviders.xAI`, `AIProviders.mistral`, `AIProviders.groq`,
`AIProviders.deepSeek`, `AIProviders.openAICompatible`. The matrix also shows
which capabilities (language, embedding, image, speech, transcription, video,
reranking, …) each provider supports. Use model IDs the provider actually
offers; do not guess them.

For string model IDs, register providers once:

```swift
let registry = createProviderRegistry([
    "openai": try AIProviders.openAI(),
    "anthropic": try AIProviders.anthropic(),
])
AIDefaultProvider.set(registry)

let answer = try await AI.generateText(
    model: "anthropic:claude-opus-5-5",
    prompt: "Write a release checklist."
)
```

## Credentials

Factories read the upstream environment variables by default, for example
`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GOOGLE_GENERATIVE_AI_API_KEY` or
`GEMINI_API_KEY`. Each provider page lists its variables.

Pass credentials explicitly when you need per-environment keys, custom headers,
a custom base URL or a mock transport:

```swift
let provider = try AIProviders.openAI(
    settings: ProviderSettings(apiKey: apiKey)
)
```

Never hard-code real keys in source, tests or examples. Read them from the
environment, the Keychain or your app's secret store. A missing key surfaces as
`AIError.missingAPIKey`.

## Generate text

```swift
let result = try await model.generateText("Write one sentence about Swift concurrency.")
print(result.text)
```

`TextGenerationResult` also exposes `content`, `reasoning`, `finishReason`,
`usage`, `toolCalls`, `toolResults`, `steps`, `responseMessages`, `warnings`
and provider/response metadata. Pass `LanguageGenerationOptions` for
`temperature`, `maxOutputTokens`, `stopSequences`, `seed`, `headers` and
documented `providerOptions`:

```swift
let result = try await model.generateText(
    "Be concise.",
    options: LanguageGenerationOptions(
        providerOptions: ["openai": ["store": false]]
    )
)
```

## Stream text

`streamText` returns an async sequence of stream parts. Handle the cases you
need and keep a `default` branch, because new documented cases are added over
time:

```swift
for try await part in model.streamText("Write a short haiku about APIs.") {
    switch part {
    case .textDeltaPart(_, let text, _):
        print(text, terminator: "")
    case .finishMetadata(let reason, let usage, _):
        print("\nFinished: \(reason ?? "unknown"), tokens: \(usage?.totalTokens ?? 0)")
    default:
        break
    }
}
```

Built-in providers emit the canonical `textStart` → `textDeltaPart` → `textEnd`
lifecycle and terminate with `finishMetadata`. The legacy `textDelta` and
`finish` cases remain for custom-model source compatibility; facade calls
normalize them to canonical events.

## Structured output

Use `Output` on `generateText` or `streamText` to get typed Swift values.
Describe the shape with `AIJSONSchema` and a `Decodable` type:

```swift
struct Summary: Decodable, Sendable {
    var title: String
    var bullets: [String]
}

let schema = AIJSONSchema<Summary>(
    [
        "type": "object",
        "properties": [
            "title": ["type": "string"],
            "bullets": ["type": "array", "items": ["type": "string"]],
        ],
        "required": ["title", "bullets"],
    ],
    name: "summary"
)

let result = try await model.generateText(
    "Summarize the SwiftAISDK README.",
    output: Output.object(schema: schema.jsonSchema, name: schema.name, as: Summary.self)
)
print(result.output.bullets)
```

Other strategies: `Output.text()`, `Output.array(element:minItems:maxItems:as:)`,
`Output.choice(choices:)` and `Output.json()`. Prefer `Output` in new code;
`generateObject` and `streamObject` still work but emit deprecation warnings.
Parsing and validation failures throw `AIObjectGenerationError`.

## Tools

Define tools with `AITool` (name, description, JSON Schema `parameters`, async
execute closure) and enable a tool loop with `LanguageToolOptions`:

```swift
let weather = AITool(
    name: "weather",
    description: "Get the current weather in a city.",
    parameters: [
        "type": "object",
        "properties": ["city": ["type": "string"]],
        "required": ["city"],
    ]
) { arguments in
    let city = arguments["city"]?.stringValue ?? "unknown"
    return ["city": .string(city), "forecast": "sunny", "temperatureCelsius": 24]
}

let answer = try await model.generateText(
    "What should I wear in Tokyo today?",
    tools: LanguageToolOptions([weather], maxSteps: 3)
)
print(answer.text)
```

Always set `maxSteps` so the model can call the tool and then answer.
`LanguageToolOptions` also takes `stopWhen` and `prepareStep`. Inspect
`steps`, `toolCalls` and `toolResults` on the result, and append
`responseMessages` to continue a conversation. Read `/core/tools.md` for
approvals, tool choice, concurrency and provider-defined tools.

## Errors, retries and cancellation

- `AIError` is the main cross-provider error enum (`missingAPIKey`,
  `unsupportedModel`, `invalidArgument`, `invalidResponse`, `apiCall`,
  `timeout`, …).
- `AIAbortError` reports cancellation through `AIAbortController`;
  `AIRetryError` reports exhausted retries; tool errors include
  `AINoSuchToolError` and `AIInvalidToolInputError`.
- Configure `retryPolicy` and `timeoutNanoseconds` on the request options.
- Do not log full requests or responses that may contain API keys or user data.

Read `/core/error-handling.md` for the full list and stream error semantics.

## Working rules

1. Fetch the relevant `.md` page before using an API you have not verified.
2. Keep provider-specific behavior in documented `providerOptions`; use
   `extraBody` only as a last resort.
3. Handle `default` in switches over SwiftAISDK enums.
4. Build with `swift build` and run tests with `swift test` after changes.
5. Use live provider calls only when the user has supplied credentials.
