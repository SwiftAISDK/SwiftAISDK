# HeyGen for Swift

`SwiftAIHeyGen` adds HeyGen to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/heygen` and supports video generation and decisions.

Provider guide with models, options, streaming and errors:

- [HeyGen](https://swiftaisdk.github.io/SwiftAISDK/providers/heygen/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIHeyGen` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIHeyGen

let provider = try AIProviders.heyGen(configuration: HeyGenProviderSettings())
```

By default the provider reads `HEYGEN_API_KEY` from the environment; values set in `HeyGenProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-heygen` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
