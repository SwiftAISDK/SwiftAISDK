# Azure OpenAI for Swift

`SwiftAIAzure` adds Azure OpenAI to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/azure` and supports text generation, text completion, embeddings, image generation, transcription and speech.

Provider guide with models, options, streaming and errors:

- [Azure OpenAI](https://swiftaisdk.github.io/SwiftAISDK/providers/azure/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIAzure` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIAzure

let provider = try AIProviders.azure(
    resourceName: "my-resource",
    configuration: AzureOpenAIProviderSettings()
)
```

By default the provider reads `AZURE_API_KEY` and `AZURE_RESOURCE_NAME` from the environment; values set in the provider settings take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-azure` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
