# SwiftAIBlackForestLabs

Swift-native port of `@ai-sdk/black-forest-labs`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIBlackForestLabs

let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-black-forest-labs
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/black-forest-labs.md) for authentication, options and supported surfaces.
## Behavior notes

Image submissions without `polling_url` use the configured `/get_result?id=...` endpoint. Only that fallback retries registration delays reported as `Task not found`, for at most 20 attempts and within the polling timeout. Explicit polling URLs and unrelated HTTP 404 errors fail without those retries.
