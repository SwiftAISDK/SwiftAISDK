# Swift AI OpenAI

An independent Swift-native port of the provider-facing Vercel AI SDK package
`@ai-sdk/openai`. Responses and chat, completions, embeddings, images, transcription/speech, decisions/evaluation, batches, files, skills and the existing OpenAI Live WebSocket adapter.

This is an extracted **local development package**, not a published modular
release. The proposed distribution URL is not an installation instruction yet.
Swift 6.3 or newer; declared platforms macOS 12 and iOS 15. M3 was verified with
Swift 6.4, including compilation for iOS Simulator; see the canonical migration report.

## Local use

Add `.package(path: "path/to/Packages/swift-ai-openai")` and depend on
`.product(name: "SwiftAIOpenAI", package: "swift-ai-openai")`.
For generation and explicit registries also add the local `swift-ai-core` package
and its `SwiftAI` product. The canonical [example](../../Examples/OpenAIOnly)
contains a complete manifest and runs offline with an injected transport.

```swift
import SwiftAI
import SwiftAIOpenAI

let provider = try AIProviders.openAI(
    configuration: OpenAIProviderSettings(apiKey: "your-api-key")
)
let model = try provider.languageModel("your-model-id")
let result = try await AI.generateText(
    model: model,
    request: .init(messages: [.user("Hello")])
)
```

Native factories use typed `configuration:` settings. The legacy `settings:`
overloads belong to `SwiftAISDK`. When importing both facades, qualify `SwiftAI.AI`
or `SwiftAISDK.AI` and the appropriate factory namespace. Core uses explicit model
objects or registries; it does not initialize an implicit Gateway.

OpenAI depends on the generic compatible package for shared wire behavior; its
runtime does not depend on Anthropic, the aggregate, MCP or UI. Provider-specific
model catalogs, authentication/defaults, Responses and audio behavior are owned here.
`OpenAIProvider` is the native concrete factory type; the legacy OpenAI factory's
`SwiftAISDK.OpenAICompatibleProvider` return type remains unchanged.

## Porting and verification

Run `swift test --package-path Packages/swift-ai-openai --no-parallel` from the
canonical checkout. Full verification is `node Scripts/test-packages.mjs`, followed
by `node Scripts/verify-provider-isolation.mjs` and
`node Scripts/verify-provider-versions.mjs`. The latter uses synthetic local Git
tags, not released version histories.

`Porting/map.json` owns source/test/fixture relationships. Reviewed npm versions,
archive evidence and test snapshot dispositions remain in the canonical
`Porting/upstream-lock.json`. Extraction does not advance baselines or claim new
upstream parity. Cross-package wire APIs support port adapters; prefer the typed
provider factory for application code.

Licensed under Apache-2.0; see LICENSE. Vercel names identify provenance, not
affiliation. Contribute through the canonical SwiftAISDK repository. Proposed
distribution repositories will be generated from it.
