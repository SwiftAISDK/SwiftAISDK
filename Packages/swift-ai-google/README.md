# SwiftAIGoogle

Swift-native port of the Google adapter from the Vercel AI SDK.

Canonical sources and behavior tests are maintained in
[SwiftAISDK/SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK). This directory is
exported as an independently versioned Swift package. Swift releases and npm
baselines are separate; published release records are in the canonical `Releases/sets`.

```swift
import SwiftAIGoogle
let provider = try AIProviders.google(configuration: GoogleProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

Existing upstream baseline, capability limits and native adaptations remain recorded
in `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/google-generative-ai.md) for authentication, options and supported surfaces.
