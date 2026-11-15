# Together AI for Swift

`SwiftAITogetherAI` adds Together AI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/togetherai` and supports text generation, text completion, embeddings, image generation and reranking.

Provider guide with models, options, streaming and errors:

- [Together AI](https://swiftaisdk.github.io/SwiftAISDK/providers/togetherai/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAITogetherAI` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAITogetherAI

let provider = try AIProviders.togetherAI(configuration: TogetherAIProviderSettings())
```

By default the provider reads `TOGETHER_API_KEY` and `TOGETHER_AI_API_KEY` from the environment; values set in `TogetherAIProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-togetherai` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
