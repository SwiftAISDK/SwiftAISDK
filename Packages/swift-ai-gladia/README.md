# Gladia for Swift

`SwiftAIGladia` adds Gladia to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/gladia` and supports transcription.

Provider guide with models, options, streaming and errors:

- [Gladia](https://swiftaisdk.github.io/SwiftAISDK/providers/gladia/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIGladia` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIGladia

let provider = try AIProviders.gladia(configuration: GladiaProviderSettings())
```

By default the provider reads `GLADIA_API_KEY` from the environment; values set in `GladiaProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-gladia` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
