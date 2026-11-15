# Replicate for Swift

`SwiftAIReplicate` adds Replicate to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/replicate` and supports image generation and video generation.

Provider guide with models, options, streaming and errors:

- [Replicate](https://swiftaisdk.github.io/SwiftAISDK/providers/replicate/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIReplicate` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIReplicate

let provider = try AIProviders.replicate(configuration: ReplicateProviderSettings())
```

By default the provider reads `REPLICATE_API_TOKEN` from the environment; values set in `ReplicateProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-replicate` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
