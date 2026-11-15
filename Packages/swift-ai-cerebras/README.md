# Cerebras for Swift

`SwiftAICerebras` adds Cerebras to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/cerebras` and supports text generation.

Provider guide with models, options, streaming and errors:

- [Cerebras](https://swiftaisdk.github.io/SwiftAISDK/providers/cerebras/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAICerebras` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAICerebras

let provider = try AIProviders.cerebras(configuration: CerebrasProviderSettings())
```

By default the provider reads `CEREBRAS_API_KEY` from the environment; values set in `CerebrasProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-cerebras` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
