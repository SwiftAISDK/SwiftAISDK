# QuiverAI for Swift

`SwiftAIQuiverAI` adds QuiverAI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/quiverai` and supports text generation and image generation.

Provider guide with models, options, streaming and errors:

- [QuiverAI](https://swiftaisdk.github.io/SwiftAISDK/providers/quiverai/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIQuiverAI` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIQuiverAI

let provider = try AIProviders.quiverAI(configuration: QuiverAIProviderSettings())
```

By default the provider reads `QUIVERAI_API_KEY` and `QUIVERAI_BASE_URL` from the environment; values set in `QuiverAIProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-quiverai` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
