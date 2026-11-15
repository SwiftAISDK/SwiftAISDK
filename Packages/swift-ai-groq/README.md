# Groq for Swift

`SwiftAIGroq` adds Groq to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/groq` and supports text generation and transcription.

Provider guide with models, options, streaming and errors:

- [Groq](https://swiftaisdk.github.io/SwiftAISDK/providers/groq/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIGroq` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIGroq

let provider = try AIProviders.groq(configuration: GroqProviderSettings())
```

By default the provider reads `GROQ_API_KEY` from the environment; values set in `GroqProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-groq` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
