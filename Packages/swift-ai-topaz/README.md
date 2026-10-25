# SwiftAITopaz

Swift-native port of `@ai-sdk/topaz`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAITopaz

let provider = try TopazProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-topaz
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/topaz.md) for authentication, options and supported surfaces.
