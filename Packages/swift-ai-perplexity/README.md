# Perplexity for Swift

`SwiftAIPerplexity` adds Perplexity to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/perplexity` and supports text generation, embeddings and decisions.

Provider guide with models, options, streaming and errors:

- [Perplexity](https://swiftaisdk.github.io/SwiftAISDK/providers/perplexity/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIPerplexity` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIPerplexity

let provider = try AIProviders.perplexity(configuration: PerplexityProviderSettings())
```

By default the provider reads `PERPLEXITY_API_KEY` from the environment; values set in `PerplexityProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-perplexity` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
