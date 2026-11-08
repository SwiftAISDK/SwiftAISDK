# SwiftAIElevenLabs

Swift-native port of `@ai-sdk/elevenlabs`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIElevenLabs

let provider = try ElevenLabsProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-elevenlabs
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/elevenlabs.md) for authentication, options and supported surfaces.
## Behavior notes

`providerOptions.elevenlabs.sourceUrl` sends `source_url` instead of uploading a file. A nonempty audio input is ignored with a warning when this option is present; nil or null retains file upload.
