# Mistral AI for Swift

`SwiftAIMistral` adds Mistral AI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/mistral` and supports text generation, embeddings, transcription and speech.

Provider guide with models, options, streaming and errors:

- [Mistral AI](https://swiftaisdk.github.io/SwiftAISDK/providers/mistral/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIMistral` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIMistral

let provider = try AIProviders.mistral(configuration: MistralProviderSettings())
```

By default the provider reads `MISTRAL_API_KEY` from the environment; values set in `MistralProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-mistral` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
