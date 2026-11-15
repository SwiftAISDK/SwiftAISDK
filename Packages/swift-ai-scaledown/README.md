# ScaleDown for Swift

`SwiftAIScaleDown` adds ScaleDown to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/scaledown` and supports decisions and extraction.

Provider guide with models, options, streaming and errors:

- [ScaleDown](https://swiftaisdk.github.io/SwiftAISDK/providers/scaledown/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIScaleDown` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIScaleDown

let provider = try AIProviders.scaleDown(configuration: ScaleDownProviderSettings())
```

By default the provider reads `SCALEDOWN_API_KEY` from the environment; values set in `ScaleDownProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-scaledown` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
