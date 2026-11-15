# OpenAI for Swift

`SwiftAIOpenAI` adds OpenAI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/openai` and supports text generation, text completion, embeddings, image generation, transcription, speech, evaluation, decisions, extraction, provider files and skills.

Provider guide with models, options, streaming and errors:

- [OpenAI](https://swiftaisdk.github.io/SwiftAISDK/providers/openai/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIOpenAI` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIOpenAI

let provider = try AIProviders.openAI(configuration: OpenAIProviderSettings())
```

By default the provider reads `OPENAI_API_KEY` and `OPENAI_BASE_URL` from the environment; values set in `OpenAIProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-openai` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
