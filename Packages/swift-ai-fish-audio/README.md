# Fish Audio for Swift

`SwiftAIFishAudio` adds Fish Audio to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/fish-audio` and supports transcription and speech.

Provider guide with models, options, streaming and errors:

- [Fish Audio](https://swiftaisdk.github.io/SwiftAISDK/providers/fish-audio/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIFishAudio` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIFishAudio

let provider = try AIProviders.fishAudio(configuration: FishAudioProviderSettings())
```

By default the provider reads `FISH_AUDIO_API_KEY` from the environment; values set in `FishAudioProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-fish-audio` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
