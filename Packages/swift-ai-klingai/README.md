# Kling AI for Swift

`SwiftAIKlingAI` adds Kling AI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/klingai` and supports video generation.

Provider guide with models, options, streaming and errors:

- [Kling AI](https://swiftaisdk.github.io/SwiftAISDK/providers/klingai/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIKlingAI` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIKlingAI

let provider = try AIProviders.klingAI(configuration: KlingAIProviderSettings())
```

By default the provider reads `KLINGAI_API_KEY`, `KLINGAI_ACCESS_KEY` and `KLINGAI_SECRET_KEY` from the environment; values set in `KlingAIProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-klingai` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
