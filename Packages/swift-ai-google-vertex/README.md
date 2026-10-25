# SwiftAIGoogleVertex

Swift-native port of Vercel AI SDK Google Vertex adapters. Canonical sources are exported as an independent Swift package. Dependencies share Google, Anthropic
and compatible/OpenAI wire implementations rather than copying them.

```swift
import SwiftAIGoogleVertex
let provider = try AIProviders.googleVertex(configuration: GoogleVertexProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

Existing port capabilities, platform adaptations and gaps remain authoritative.
See the canonical provider guide and `Porting/map.json`.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/google-vertex.md) for authentication, options and supported surfaces.
