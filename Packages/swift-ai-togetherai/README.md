# SwiftAITogetherAI

Swift-native port of `@ai-sdk/togetherai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAITogetherAI

let provider = try TogetherAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

JSON Schema output is forwarded for the exact verified catalog IDs: DeepSeek
V4 Flash 0731, V4.1 Flash and its 1017 snapshot, GPT OSS 120B, GLM 5.2 and
5.3 Flash, Kimi K3, and MiniMax M3.1 Flash. Other model IDs retain the JSON-object
fallback. Custom settings can explicitly opt additional models into schema output.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-togetherai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
