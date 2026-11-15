# Baseten for Swift

`SwiftAIBaseten` adds Baseten to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/baseten` and supports text generation and embeddings.

Provider guide with models, options, streaming and errors:

- [Baseten](https://swiftaisdk.github.io/SwiftAISDK/providers/baseten/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIBaseten` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIBaseten

let provider = try AIProviders.baseten(configuration: BasetenProviderSettings())
```

By default the provider reads `BASETEN_API_KEY` from the environment; values set in `BasetenProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-baseten` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
