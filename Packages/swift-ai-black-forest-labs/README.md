# SwiftAIBlackForestLabs

Swift-native port of `@ai-sdk/black-forest-labs`. Extracted during M6; not yet published.

```swift
import SwiftAIBlackForestLabs

let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-black-forest-labs
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
