# SwiftAIReplicate

Swift-native port of `@ai-sdk/replicate`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIReplicate

let provider = try ReplicateProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-replicate
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
