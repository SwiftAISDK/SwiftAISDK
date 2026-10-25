# SwiftAIXAI

Swift-native port of `@ai-sdk/xai`. Extracted during M6; not yet published.

```swift
import SwiftAIXAI

let provider = try XAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Responses request policy, legacy Chat behavior, Files, Batch, realtime and media
adapters belong to this package. It composes the public `SwiftAIOpenAI` Responses
engine and managed-file helpers and the `SwiftAIOpenAICompatible` Chat engine;
these dependencies do not install OpenAI credentials or select OpenAI endpoints.
New code should use `languageModel` or `responses`; `chat` preserves the earlier
Swift compatibility surface removed from upstream xAI 5.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-xai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
