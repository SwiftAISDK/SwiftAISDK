# SwiftAISDK

A SwiftPM port of the provider-facing [Vercel AI SDK](https://github.com/vercel/ai).
Use provider factories and the `AI` facade for text and streaming, structured
output, tools, embeddings, media, realtime audio, and MCP.

**[Documentation](https://swiftaisdk.github.io/SwiftAISDK/)** ·
[Providers](https://swiftaisdk.github.io/SwiftAISDK/providers/) ·
[Examples](Examples) ·
[Releases](https://github.com/SwiftAISDK/SwiftAISDK/releases)

Requires Swift 6.3+, macOS 12+ or iOS 15+. Provider-specific availability and
limitations are described in the documentation.

## Install

Add the complete `SwiftAISDK` package to `Package.swift`:

```swift
.package(url: "https://github.com/SwiftAISDK/SwiftAISDK.git", from: "3.6.0")
```

Add its product to your target's dependencies:

```swift
.product(name: "SwiftAISDK", package: "SwiftAISDK")
```

For a smaller dependency graph, select core and just the providers you need
from the [package catalog](Docs/PackageCatalog.md). The
[installation guide](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/)
covers native imports and credentials; the [migration guide](Docs/Migration.md)
explains the 3.x compatibility umbrella and the 2.x boundary.

Applications should commit `Package.resolved` to preserve the complete dependency
graph. An exact umbrella version alone does not pin its dependencies. Swift
package versions are independent of upstream npm versions; verified selections
are recorded in [release sets](Releases/sets).

## Quick start

Set `OPENAI_API_KEY` in your environment, then generate text:

```swift
import SwiftAISDK

let provider = try AIProviders.openAI()
let model = try provider.languageModel("gpt-4.1")
let result = try await model.generateText("Write one sentence about Swift.")

print(result.text)
```

Choose another provider by changing the factory and model ID. See the
[quickstart](https://swiftaisdk.github.io/SwiftAISDK/getting-started/quickstart/)
and [provider guides](https://swiftaisdk.github.io/SwiftAISDK/providers/)
for configuration and supported capabilities.

## Guides

| Goal | Documentation |
| --- | --- |
| Generate and stream text | [Text](https://swiftaisdk.github.io/SwiftAISDK/core/generate-text/), [streaming](https://swiftaisdk.github.io/SwiftAISDK/core/stream-text/) |
| Decode typed results | [Structured output](https://swiftaisdk.github.io/SwiftAISDK/core/structured-output/) |
| Execute tools and connect MCP servers | [Tools](https://swiftaisdk.github.io/SwiftAISDK/core/tools/), [MCP](https://swiftaisdk.github.io/SwiftAISDK/cookbook/mcp-tools/) |
| Work with embeddings and search | [Embeddings](https://swiftaisdk.github.io/SwiftAISDK/core/embeddings/), [reranking](https://swiftaisdk.github.io/SwiftAISDK/core/rerank/) |
| Generate images, video, and audio | [Images](https://swiftaisdk.github.io/SwiftAISDK/core/generate-image/), [video](https://swiftaisdk.github.io/SwiftAISDK/core/generate-video/), [speech](https://swiftaisdk.github.io/SwiftAISDK/core/generate-speech/), [transcription](https://swiftaisdk.github.io/SwiftAISDK/core/transcribe/) |
| Manage durable work and files | [Batches](https://swiftaisdk.github.io/SwiftAISDK/core/batch-text/), [files](https://swiftaisdk.github.io/SwiftAISDK/core/files/) |
| Extract fields and answer typed questions | [Extraction](https://swiftaisdk.github.io/SwiftAISDK/core/extract/), [decisions](https://swiftaisdk.github.io/SwiftAISDK/core/decide/), [evaluation](https://swiftaisdk.github.io/SwiftAISDK/core/evaluate/) |
| Connect realtime audio | [Realtime sessions](https://swiftaisdk.github.io/SwiftAISDK/core/realtime/) |
| Customize runtime behavior and chat state | [Middleware](https://swiftaisdk.github.io/SwiftAISDK/components/middleware/), [chat and UI messages](https://swiftaisdk.github.io/SwiftAISDK/components/chat-and-ui-messages/) |
| Diagnose failures | [Errors](https://swiftaisdk.github.io/SwiftAISDK/core/error-handling/), [troubleshooting](https://swiftaisdk.github.io/SwiftAISDK/troubleshooting/) |

Capability support varies by provider. Consult the
[capability matrix](Docs/ProviderCapabilityMatrix.md) and
[porting status](Docs/PortingStatus.md) for coverage and known gaps.

## Development

Edit this canonical repository; distribution repositories are generated from
`Packages/*`. Build local sources and run all package and compatibility tests:

```sh
node Scripts/sdk.mjs dev build
node Scripts/test-packages.mjs
```

Runnable samples live in [Examples](Examples). Optional live checks require
`LIVE_AI_TESTS=1`; see the [porting guide](Docs/AgentPortingGuide.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, validation, and review expectations,
and [AGENTS.md](AGENTS.md) for agent rules. The [documentation map](Docs/README.md),
[porting guide](Docs/AgentPortingGuide.md), and
[release workflow](Releases/README.md) cover maintenance and verification.

## License

[Apache License 2.0](LICENSE). SwiftAISDK is an independent Swift port;
references to Vercel AI SDK describe compatibility and provenance, not
affiliation or endorsement.
