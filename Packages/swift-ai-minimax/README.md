# SwiftAIMiniMax

Swift-native port of `@ai-sdk/minimax`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIMiniMax

let provider = try MiniMaxProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
capabilities and documented gaps remain documented in the provider guide.

`MiniMaxLanguageModelOptions(serviceTier: .priority)` requests priority admission;
`.standard` requests standard admission. Both map to `service_tier` for unary and
streaming Messages. Omit the field for the API default. Priority admission carries
the provider's higher tariff. The `minimax` namespace overrides `anthropic` options;
Anthropic-only admission values produce an unsupported-setting warning.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-minimax
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/minimax.md) for authentication, options and supported surfaces.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

## Current upstream review

The reviewed baseline is `@ai-sdk/minimax` 3.0.81. `image("MiniMax-H3-Image")` and `imageModel("MiniMax-H3-Image-Highspeed")` now support text-to-image and reference-image editing. `MiniMaxProviderSettings.imageBaseURL` defaults to `https://api.minimax.io/v1`; the existing settings initializer selector remains available.

```swift
let image = try await provider.image("MiniMax-H3-Image").generateImage(.init(
    prompt: "A red circle", aspectRatio: "1:1", count: 2,
    providerOptions: MiniMaxImageModelOptions(area: .twoK, outputFormat: .png).providerOptions
))
```

Requests use `/images/generations` or `/images/edits`, always request URL output and securely download successful images through the configured transport. Bearer tokens and provider headers are omitted from downloads. Results contain normalized base64 images, per-image size/revised prompt, output format/request ID and usage details (request usage appears once in per-image metadata).

The maximum advertised batch size is ten. Individual image failures become warnings while successful images survive; seed is unsupported, masks fail before HTTP, and edits warn and omit the generation-only prompt-enhancement option. Compression accepts integers from 0 through 100. Async credentials continue to resolve only for authenticated provider requests.
