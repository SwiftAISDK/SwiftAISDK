# Topaz Labs for Swift

`SwiftAITopaz` adds Topaz Labs to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/topaz` and supports image generation and video generation.

Provider guide with models, options, streaming and errors:

- [Topaz Labs](https://swiftaisdk.github.io/SwiftAISDK/providers/topaz/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAITopaz` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAITopaz

let provider = try AIProviders.topaz(configuration: TopazProviderSettings())
```

By default the provider reads `TOPAZ_API_KEY` from the environment; values set in `TopazProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-topaz` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
