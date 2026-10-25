# SwiftAIGoogleVertex

Swift-native port of Vercel AI SDK Google Vertex adapters. M6 extraction is in
progress; this package is not yet published. Dependencies share Google, Anthropic
and compatible/OpenAI wire implementations rather than copying them.

```swift
import SwiftAIGoogleVertex
let provider = try AIProviders.googleVertex(configuration: GoogleVertexProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

Existing port capabilities, platform adaptations and gaps remain authoritative.
See the canonical provider guide and `Porting/map.json`.
