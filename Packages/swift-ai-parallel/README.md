# Parallel for Swift

`SwiftAIParallel` adds Parallel to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/parallel` and supports decisions.

Provider guide with models, options, streaming and errors:

- [Parallel](https://swiftaisdk.github.io/SwiftAISDK/providers/parallel/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIParallel` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIParallel

let provider = try AIProviders.parallel(configuration: ParallelProviderSettings())
```

By default the provider reads `PARALLEL_API_KEY` from the environment; values set in `ParallelProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-parallel` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
