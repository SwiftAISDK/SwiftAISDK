## Quick start

```swift
import Foundation
import SwiftAISDK

let provider = try AIProviders.lmnt() // reads LMNT_API_KEY
let model = try provider.speechModel("aurora")
let result = try await model.generateSpeech("Hello from Swift!", voice: "ava")
try result.audio.write(to: URL(fileURLWithPath: "hello.mp3"))
```

With modular packages, `import SwiftAI` and `import SwiftAILMNT`, then call
`AIProviders.lmnt(configuration: LMNTProviderSettings(...))`. The native factory
requires the `configuration` argument; pass `LMNTProviderSettings()` to read
`LMNT_API_KEY`.

## Umbrella and native providers

The two factories return different provider types:

| Factory | Returns | Settings |
| --- | --- | --- |
| `AIProviders.lmnt(settings:)` (umbrella) | `OpenAICompatibleProvider` | `ProviderSettings` |
| `AIProviders.lmnt(configuration:)` (native) | `LMNTProvider` | `LMNTProviderSettings` |

Both create speech models with `speechModel(_:)`, and both need a model ID such as
`aurora` or `blizzard`. On the umbrella provider, `speechModel()` with no argument
throws because LMNT requires a model ID. Every other model family throws
`AIError.unsupportedModel`. Both settings types accept `apiKey`, `baseURL`,
`headers`, `queryParams` and `transport`. LMNT has no rotating-key closure.

## Speech requests

Requests go to `/v1/ai/speech/bytes` with the key in the `x-api-key` header, and
the raw audio bytes are returned.

- `voice` defaults to `ava`.
- `format` accepts `mp3`, `aac`, `mulaw`, `raw` and `wav`. Other values fall back
  to `mp3` with a warning.
- `speed` and `language` are forwarded.

## Provider options

`providerOptions["lmnt"]` accepts `sampleRate` (8000, 16000 or 24000), `speed`
(0.25–2), `seed` (integer), `conversational`, `length` (up to 300), `topP` (0–1)
and `temperature` (0 or higher). Invalid values throw `AIError.invalidArgument`
before the request is sent.

```swift
let result = try await model.generateSpeech(
    "Let's keep this casual.",
    providerOptions: ["lmnt": ["conversational": true, "sampleRate": 16_000]]
)
```

When you pass `providerOptions["lmnt"]`, any key you leave out uses its default:
`sampleRate` 24000, `speed` 1, `conversational` false, `topP` 1 and
`temperature` 1. A provider-options `speed` overrides the top-level `speed`.
`model` and `format` are validated but not sent; use the model ID and the
`format` argument instead.
