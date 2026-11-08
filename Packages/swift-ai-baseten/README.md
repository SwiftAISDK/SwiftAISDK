# SwiftAIBaseten

Swift-native port of `@ai-sdk/baseten`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIBaseten

let provider = try BasetenProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-baseten
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
## Behavior notes

Chat requests accept `providerOptions.baseten` and portable reasoning options. For the serverless `deepseek-ai/DeepSeek-V4-Pro-0813` endpoint, JSON output with reasoning enabled uses an injected system instruction instead of server JSON constraints and returns a compatibility warning. Explicit reasoning `none`, other models and dedicated `modelURL` deployments retain their response format.
