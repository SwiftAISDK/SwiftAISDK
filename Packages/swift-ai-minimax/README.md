# SwiftAIMiniMax

Swift-native port of `@ai-sdk/minimax`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIMiniMax

let provider = try MiniMaxProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
capabilities and documented gaps remain documented in the provider guide.

`MiniMaxLanguageModelOptions(serviceTier: .priority)` requests priority admission;
`.standard` requests standard admission. Both map to `service_tier` for unary and
streaming Messages. Omit the field for the API default. Priority admission carries
the provider's higher tariff. The `minimax` namespace overrides `anthropic` options;
Anthropic-only admission values produce an unsupported-setting warning.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-minimax
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/minimax.md) for authentication, options and supported surfaces.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.
