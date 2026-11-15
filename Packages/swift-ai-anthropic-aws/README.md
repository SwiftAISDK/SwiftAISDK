# Claude Platform on AWS for Swift

`SwiftAIAnthropicAWS` adds Claude Platform on AWS to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/anthropic-aws` and supports text generation, provider files and skills.

Provider guide with models, options, streaming and errors:

- [Claude Platform on AWS](https://swiftaisdk.github.io/SwiftAISDK/providers/anthropic-aws/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIAnthropicAWS` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIAnthropicAWS

let provider = try AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings())
```

By default the provider reads `ANTHROPIC_AWS_WORKSPACE_ID`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `ANTHROPIC_AWS_API_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` from the environment; values set in `AnthropicAWSProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-anthropic-aws` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
