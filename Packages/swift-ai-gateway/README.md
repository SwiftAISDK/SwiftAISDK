# Vercel AI Gateway for Swift

`SwiftAIGateway` adds Vercel AI Gateway to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/gateway` and supports text generation, embeddings, image generation, transcription, speech, video generation, reranking, evaluation and decisions.

Provider guide with models, options, streaming and errors:

- [Vercel AI Gateway](https://swiftaisdk.github.io/SwiftAISDK/providers/gateway/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIGateway` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIGateway

let provider = try AIProviders.gateway(configuration: GatewayProviderSettings())
```

By default the provider reads `AI_GATEWAY_API_KEY` and `VERCEL_OIDC_TOKEN` from the environment; values set in `GatewayProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-gateway` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
