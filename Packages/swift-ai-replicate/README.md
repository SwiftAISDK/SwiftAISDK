# SwiftAIReplicate

Swift-native port of `@ai-sdk/replicate`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIReplicate

let provider = try ReplicateProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-replicate
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
## Behavior notes

Aborted or exhausted image polling starts best-effort cancellation at the configured prediction endpoint. Cancellation resolves provider credentials again, omits per-call headers and the aborted signal, and preserves the original generation error. Response-supplied cancel URLs are ignored. Image and video seed zero remains a valid explicit seed.
