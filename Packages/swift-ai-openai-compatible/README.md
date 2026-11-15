# OpenAI-compatible servers for Swift

`SwiftAIOpenAICompatible` adds OpenAI-compatible servers to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/openai-compatible` and supports text generation, text completion, embeddings and image generation.

Provider guide with models, options, streaming and errors:

- [OpenAI-compatible servers](https://swiftaisdk.github.io/SwiftAISDK/providers/openai-compatible/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIOpenAICompatible` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIOpenAICompatible

let provider = try AIProviders.openAICompatible(configuration: OpenAICompatibleProviderSettings(
    name: "my-server",
    baseURL: "https://example.com/v1"
))
```

Pass credentials in `OpenAICompatibleProviderSettings`; the guide shows the supported options.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-openai-compatible` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
