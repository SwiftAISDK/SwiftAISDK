# Z.AI for Swift

`SwiftAIZAI` adds Z.AI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/zai` and supports text generation.

Provider guide with models, options, streaming and errors:

- [Z.AI](https://swiftaisdk.github.io/SwiftAISDK/providers/zai/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIZAI` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIZAI

let provider = try AIProviders.zai(configuration: ZAIProviderSettings())
```

By default the provider reads `ZAI_API_KEY` from the environment; values set in `ZAIProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-zai` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
