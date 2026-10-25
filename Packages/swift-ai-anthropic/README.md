# Swift AI Anthropic

An independent Swift-native port of the provider-facing Vercel AI SDK package
`@ai-sdk/anthropic`. Messages, streaming, tools, structured output, decisions/evaluation, batches, file upload and skills.

This is an extracted **local development package**, not a published modular
release. The proposed distribution URL is not an installation instruction yet.
Swift 6.3 or newer; declared platforms macOS 12 and iOS 15. M3 was verified with
Swift 6.4, including compilation for iOS Simulator; see the canonical migration report.

## Local use

Add `.package(path: "path/to/Packages/swift-ai-anthropic")` and depend on
`.product(name: "SwiftAIAnthropic", package: "swift-ai-anthropic")`.
For generation and explicit registries also add the local `swift-ai-core` package
and its `SwiftAI` product. The canonical [example](../../Examples/AnthropicOnly)
contains a complete manifest and runs offline with an injected transport.

```swift
import SwiftAI
import SwiftAIAnthropic

let provider = try AIProviders.anthropic(
    configuration: AnthropicProviderSettings(apiKey: "your-api-key")
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

Runtime dependencies are core contracts, transport and utilities only. Bedrock,
Vertex and MiniMax policy remains with those hosting providers; wire adapter
configuration allows the aggregate to reuse Messages behavior without a reverse
provider dependency. File support remains upload-only.

## Porting and verification

Run `swift test --package-path Packages/swift-ai-anthropic --no-parallel` from the
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
