# SwiftAIOpenResponses

Swift-native port of `@ai-sdk/open-responses`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIOpenResponses

let provider = try OpenResponsesProvider(name: "local", url: "https://example.com/responses",
                                         configuration: .init(apiKey: "..."))
let model = try provider.languageModel("local-model")
```

This package owns endpoint configuration, generic Responses mode, custom tools and
its ported tests. It reuses the existing shared Responses engine through
`SwiftAIOpenAI`'s public hosting API. That dependency does not add OpenAI credentials,
model routing or wire policy. It avoids a second engine to synchronize. A future
engine move would require a separate compatibility migration.

The existing extension-codec gap remains documented in the canonical capability
matrix. Run `swift test --package-path Packages/swift-ai-open-responses` in the
canonical checkout. Distribution manifests are generated from the package catalog.
