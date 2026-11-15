# Luma AI for Swift

`SwiftAILuma` adds Luma AI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/luma` and supports image generation.

Provider guide with models, options, streaming and errors:

- [Luma AI](https://swiftaisdk.github.io/SwiftAISDK/providers/luma/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAILuma` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAILuma

let provider = try AIProviders.luma(configuration: LumaProviderSettings())
```

By default the provider reads `LUMA_API_KEY` from the environment; values set in `LumaProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-luma` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
