# Hugging Face for Swift

`SwiftAIHuggingFace` adds Hugging Face to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/huggingface` and supports text generation.

Provider guide with models, options, streaming and errors:

- [Hugging Face](https://swiftaisdk.github.io/SwiftAISDK/providers/huggingface/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIHuggingFace` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIHuggingFace

let provider = try AIProviders.huggingFace(configuration: HuggingFaceProviderSettings())
```

By default the provider reads `HUGGINGFACE_API_KEY` from the environment; values set in `HuggingFaceProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-huggingface` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
