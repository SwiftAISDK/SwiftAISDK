# Swift AI OpenAI-compatible

An independent Swift-native port of the provider-facing Vercel AI SDK package
`@ai-sdk/openai-compatible`. Generic chat, completions, embeddings and images. This package does not dispatch to built-in providers or provide OpenAI Responses, audio, files or realtime.

Swift 6.3 or newer; declared platforms macOS 12 and iOS 15. This source is
maintained in the canonical SwiftAISDK repository and exported as an independently
versioned Swift package. Swift versions are independent of the npm baselines.

## Usage

Depend on `.product(name: "SwiftAIOpenAICompatible", package: "swift-ai-openai-compatible")`.
For generation and explicit registries also add `swift-ai-core` and its `SwiftAI`
product. The canonical [example](../../Examples/OpenAICompatibleOnly) contains a complete
manifest for local development and runs offline with an injected transport.

```swift
import SwiftAI
import SwiftAIOpenAICompatible

let provider = AIProviders.openAICompatible(
    configuration: OpenAICompatibleProviderSettings(name: "custom", baseURL: "https://example.com/v1", apiKey: "your-api-key")
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

Runtime dependencies are core contracts, transport and utilities only. The native
`OpenAICompatibleProvider` requires an explicit name/base URL and does not inspect
environment variables. It is distinct from the legacy aggregate class with the
same name; qualify that type when importing both modules. OpenAI model catalog
rules and concrete host policies are supplied by adapters rather than importing
those provider implementations here.

## Porting and verification

Run `swift test --package-path Packages/swift-ai-openai-compatible --no-parallel` from the
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
affiliation. Contribute through the canonical SwiftAISDK repository. Distribution repositories are generated from it.
