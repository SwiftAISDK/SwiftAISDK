## Quick start

```swift
import SwiftAISDK

let zai = AIProviders.zai()
let model = try zai.languageModel("glm-5.3")
let result = try await model.generateText("Write a haiku about Swift.")
print(result.text)
```

For the modular packages, use `import SwiftAI` and `import SwiftAIZAI`, then
`AIProviders.zai(configuration: ZAIProviderSettings(...))`. The native factory requires a
configuration argument and does not throw; `zai` is a default provider instance.

The API key is resolved when a request is made, so creating the provider never fails for
a missing key. `ZAIProviderSettings(environment:)` supplies a custom environment map.

## GLM chat models

Z.AI serves GLM models, such as `glm-5.3`, `glm-5.2` and `glm-4.7`, through its
OpenAI-compatible Chat Completions endpoint at `https://api.z.ai/api/paas/v4`. Any model
ID string is accepted. `languageModel(_:)`, `chatModel(_:)`, `chat(_:)` and calling the
provider directly return the same model. Messages may include HTTP(S) image and video
URLs. Responses keep reasoning, text and tool calls in order; streaming delivers tool
arguments incrementally. Usage reports cached input tokens and reasoning tokens.

Only language models are available; embedding and image factories throw.

## Provider options

Options under `providerOptions["zai"]` are validated before the request:

| Option | Behavior |
| --- | --- |
| `doSample` | Boolean sampling switch. |
| `thinking` | Object with `type` (`enabled` or `disabled`) and optional Boolean `clearThinking`. |
| `reasoningEffort` | `none`, `minimal`, `low`, `medium`, `high`, `xhigh` or `max`. |
| `toolStream` | Boolean; streams tool-call arguments. |
| `requestId` | String of 6–64 characters. |
| `userId` | String of 6–128 characters. |

```swift
let result = try await model.generateText(
    "Plan a three-day trip to Kyoto.",
    options: LanguageGenerationOptions(providerOptions: ["zai": [
        "thinking": ["type": "enabled"]
    ]])
)
```

## Unsupported settings

`topK`, `frequencyPenalty`, `presencePenalty` and `seed` are removed with warnings. A JSON
response format with a schema warns because schemas are not enforced. Tool choice `none`
removes the tools; any choice other than `auto` or `none` warns, because Z.AI only
selects tools automatically.

Z.AI finish reasons `sensitive`, `model_context_window_exceeded` and `network_error` map
to `content-filter`, `length` and `error`.

## Rotating credentials

`ZAIProviderSettings.apiKeyProvider` accepts an async throwing closure resolved before
each authenticated request; the umbrella `AIProviders.zai(settings:)` factory accepts the
same settings type. A supplier failure stops the request before it is sent.
