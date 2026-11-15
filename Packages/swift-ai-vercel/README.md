# Vercel v0 for Swift

`SwiftAIVercel` adds Vercel v0 to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/vercel` and supports text generation.

Provider guide with models, options, streaming and errors:

- [Vercel v0](https://swiftaisdk.github.io/SwiftAISDK/providers/vercel/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIVercel` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIVercel

let provider = try AIProviders.vercel(configuration: VercelProviderSettings())
```

By default the provider reads `VERCEL_API_KEY` from the environment; values set in `VercelProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-vercel` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
