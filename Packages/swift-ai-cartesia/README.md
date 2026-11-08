# SwiftAICartesia

Swift-native port of `@ai-sdk/cartesia`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAICartesia

let provider = try CartesiaProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-cartesia
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/cartesia.md) for authentication, options and supported surfaces.
## Behavior notes

Speech options include `volume` (0.5–2), the supported `emotion` values, `locale`, `normalization` and `pronunciationDictionaryId`. Locale overrides the generic language with a warning and conflicts with a provider language. Streaming transcription accepts up to 100 `keyterms` plus `turnStartThreshold`, `turnEagerEndThreshold`, `turnEndThreshold` and integer `turnEndTimeoutMs`; thresholds are omitted with warnings when turn detection is disabled.
