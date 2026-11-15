# Fireworks AI for Swift

`SwiftAIFireworks` adds Fireworks AI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/fireworks` and supports text generation, text completion, embeddings and image generation.

Provider guide with models, options, streaming and errors:

- [Fireworks AI](https://swiftaisdk.github.io/SwiftAISDK/providers/fireworks/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIFireworks` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIFireworks

let provider = try AIProviders.fireworks(configuration: FireworksProviderSettings())
```

By default the provider reads `FIREWORKS_API_KEY` from the environment; values set in `FireworksProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-fireworks` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
