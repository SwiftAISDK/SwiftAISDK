# SwiftAITypeSafeAI

Swift-native port of `@ai-sdk/typesafe-ai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAITypeSafeAI

let provider = TypeSafeAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, an environment override and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-typesafe-ai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/typesafe.md) for authentication, options and supported surfaces.
## Behavior notes

Decision state preserves a single JSON object, array or string; primitive JSON state becomes text. Choice questions require 1–255 options, and score questions require 1–10 non-null levels. Score legends are exposed under `providerMetadata.typesafe.legend`. A box question may omit instructions using `.box()` (sent as native JSON null) and enables the image feature header even without image assets.
