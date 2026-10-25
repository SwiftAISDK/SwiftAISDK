# SwiftAIAzure

Swift-native port of `@ai-sdk/azure`. Extracted during M6; not yet published.

```swift
import SwiftAIAzure

let provider = try AzureOpenAIProvider(resourceName: "my-resource",
    configuration: .init(apiKey: "..."))
let model = try provider.languageModel("deployment")
```

Azure owns its deployment/Foundry routing, token transport, MAI and Speech adapters.
OpenAI/compatible and DeepSeek implementations are reused through their explicit
hosting configurations. Existing capabilities and gaps remain unchanged.

Run `swift test --package-path Packages/swift-ai-azure` in the canonical checkout.
Distribution manifests and repositories are generated from the package catalog.
