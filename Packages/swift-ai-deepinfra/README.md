# DeepInfra for Swift

`SwiftAIDeepInfra` adds DeepInfra to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/deepinfra` and supports text generation, text completion, embeddings and image generation.

Provider guide with models, options, streaming and errors:

- [DeepInfra](https://swiftaisdk.github.io/SwiftAISDK/providers/deepinfra/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIDeepInfra` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIDeepInfra

let provider = try AIProviders.deepInfra(configuration: DeepInfraProviderSettings())
```

By default the provider reads `DEEPINFRA_API_KEY` from the environment; values set in `DeepInfraProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-deepinfra` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
