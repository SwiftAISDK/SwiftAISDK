# ByteDance (BytePlus ModelArk) for Swift

`SwiftAIByteDance` adds ByteDance (BytePlus ModelArk) to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/bytedance` and supports video generation.

Provider guide with models, options, streaming and errors:

- [ByteDance (BytePlus ModelArk)](https://swiftaisdk.github.io/SwiftAISDK/providers/bytedance/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIByteDance` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIByteDance

let provider = try AIProviders.byteDance(configuration: ByteDanceProviderSettings())
```

By default the provider reads `ARK_API_KEY` from the environment; values set in `ByteDanceProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-bytedance` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
