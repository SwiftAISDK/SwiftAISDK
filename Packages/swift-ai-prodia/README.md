# Prodia for Swift

`SwiftAIProdia` adds Prodia to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/prodia` and supports text generation, image generation and video generation.

Provider guide with models, options, streaming and errors:

- [Prodia](https://swiftaisdk.github.io/SwiftAISDK/providers/prodia/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIProdia` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIProdia

let provider = try AIProviders.prodia(configuration: ProdiaProviderSettings())
```

By default the provider reads `PRODIA_TOKEN` and `PRODIA_API_KEY` from the environment; values set in `ProdiaProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-prodia` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
