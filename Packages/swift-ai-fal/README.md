# fal for Swift

`SwiftAIFal` adds fal to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/fal` and supports image generation, transcription, speech and video generation.

Provider guide with models, options, streaming and errors:

- [fal](https://swiftaisdk.github.io/SwiftAISDK/providers/fal/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIFal` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIFal

let provider = try AIProviders.fal(configuration: FalProviderSettings())
```

By default the provider reads `FAL_API_KEY` and `FAL_KEY` from the environment; values set in `FalProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-fal` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
