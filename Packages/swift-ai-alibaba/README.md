# Alibaba Cloud Model Studio (DashScope) for Swift

`SwiftAIAlibaba` adds Alibaba Cloud Model Studio (DashScope) to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/alibaba` and supports text generation, embeddings and video generation.

Provider guide with models, options, streaming and errors:

- [Alibaba Cloud Model Studio (DashScope)](https://swiftaisdk.github.io/SwiftAISDK/providers/alibaba/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIAlibaba` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIAlibaba

let provider = try AIProviders.alibaba(configuration: AlibabaProviderSettings())
```

By default the provider reads `ALIBABA_API_KEY` and `DASHSCOPE_API_KEY` from the environment; values set in `AlibabaProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-alibaba` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
