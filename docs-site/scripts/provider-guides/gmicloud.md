## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.gmiCloud()
let model = try provider.languageModel("moonshotai/kimi-k3")
let result = try await model.generateText("List three uses for a Raspberry Pi.")
print(result.text)
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIGMICloud`
with the native factory `AIProviders.gmiCloud(configuration: GMICloudProviderSettings())`.
The native factory requires the configuration argument; `GMICloudProviderSettings()`
reads `GMI_CLOUD_APIKEY` from the environment (or from its `environment`
dictionary when set).

## Chat models

GMI Cloud serves open models through an OpenAI-compatible Chat Completions API at
`https://api.gmi-serving.com/v1`, with bearer authentication. `languageModel(_:)`,
`chatModel(_:)`, `chat(_:)` and calling the provider directly
(`try provider("zai-org/GLM-5.2-FP8")`) all return the same chat model. Model IDs
are passed through unchanged, so new GMI Cloud models work without an SDK update.

- Streaming and tool calls follow the OpenAI-compatible chat contract; see
  [Stream text](../../core/stream-text/) and [Tools](../../core/tools/).
- Streamed responses always request usage. Usage fields the SDK does not recognize
  are kept in the raw usage value.
- JSON Schema output is sent natively only when you set
  `supportsStructuredOutputs: true` in the settings.
- Options under `providerOptions["openaiCompatible"]` or
  `providerOptions["gmicloud"]` (`user`, `reasoningEffort`, `textVerbosity`,
  `strictJsonSchema`) map like the generic OpenAI-compatible provider; other
  `gmicloud` keys are sent in the request body. The top-level `reasoning` option is
  sent as `reasoning_effort`.
- `transformRequestBody` lets you edit the request body before it is sent.
- Embedding and image models are not available and throw an unsupported-model
  error.

## Errors

When GMI Cloud returns a generic error with a JSON string in `error.details`, the
SDK unwraps it and uses the nested backend message, so errors show the actual
cause.

## Rotating credentials

`GMICloudProviderSettings(apiKeyProvider:)` takes an async throwing closure that
is called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
