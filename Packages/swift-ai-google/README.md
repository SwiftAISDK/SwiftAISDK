# SwiftAIGoogle

Swift-native port of the Google adapter from the Vercel AI SDK.

This package is extracted during M6 and is not yet published. Canonical sources and
behavior tests live in this repository. Public releases are recorded in `Releases/sets`.

```swift
import SwiftAIGoogle
let provider = try AIProviders.google(configuration: GoogleProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

Existing upstream baseline, capability limits and native adaptations remain recorded
in `Porting/map.json` and the canonical provider guide.
