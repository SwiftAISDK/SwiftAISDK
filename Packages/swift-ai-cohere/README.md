# Cohere for Swift

`SwiftAICohere` adds Cohere to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/cohere` and supports text generation, embeddings and reranking.

Provider guide with models, options, streaming and errors:

- [Cohere](https://swiftaisdk.github.io/SwiftAISDK/providers/cohere/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAICohere` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAICohere

let provider = try AIProviders.cohere(configuration: CohereProviderSettings())
```

By default the provider reads `COHERE_API_KEY` from the environment; values set in `CohereProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-cohere` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
