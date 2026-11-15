# Google Vertex AI for Swift

`SwiftAIGoogleVertex` adds Google Vertex AI, Google Vertex AI — Model Garden (MaaS), Google Vertex AI — xAI Grok and Google Vertex AI — Anthropic Claude to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/google-vertex` and supports text generation, embeddings, image generation, speech, transcription, video generation and text completion.

Provider guides with models, options, streaming and errors:

- [Google Vertex AI](https://swiftaisdk.github.io/SwiftAISDK/providers/google-vertex/)
- [Google Vertex AI — Model Garden (MaaS)](https://swiftaisdk.github.io/SwiftAISDK/providers/googlevertex-maas/)
- [Google Vertex AI — xAI Grok](https://swiftaisdk.github.io/SwiftAISDK/providers/googlevertex-xai/)
- [Google Vertex AI — Anthropic Claude](https://swiftaisdk.github.io/SwiftAISDK/providers/googlevertex-anthropic/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIGoogleVertex` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIGoogleVertex

let provider = try AIProviders.googleVertex(configuration: GoogleVertexProviderSettings())
```

By default the provider reads `GOOGLE_VERTEX_PROJECT`, `GOOGLE_VERTEX_LOCATION`, `GOOGLE_VERTEX_API_KEY`, `GOOGLE_VERTEX_ACCESS_TOKEN`, `GOOGLE_ACCESS_TOKEN`, `GOOGLE_CLIENT_EMAIL`, `GOOGLE_PRIVATE_KEY` and `GOOGLE_PRIVATE_KEY_ID` from the environment; values set in `GoogleVertexProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-google-vertex` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
