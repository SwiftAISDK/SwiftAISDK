# SwiftAIGateway

Swift-native port of `@ai-sdk/gateway`. Extracted during M6; not yet published.

```swift
import SwiftAIGateway

let provider = try GatewayProvider(configuration: .init(apiKey: "..."))
let model = try provider.languageModel("openai/gpt-5")
```

The package owns Gateway authentication, model and management routes, batch,
streaming audio and decision/evaluation adapters. Provider-neutral contracts and
socket lifecycle support come from `swift-ai-core`. Existing upstream baselines,
capabilities and documented gaps remain unchanged.

Run `swift test --package-path Packages/swift-ai-gateway` in the canonical checkout.
Distribution manifests and repositories are generated from the package catalog.
