## Quick start

Set `LIQUID_API_KEY`, then ask a decision question against text or structured evidence.

```swift
import SwiftAISDK

let provider = AIProviders.liquid()
let result = try await AI.experimentalDecide(
    model: .model(provider.decisionModel("d1.2")),
    state: .text("The customer's card was charged twice."),
    questions: ["refund": .boolean(instructions: "Is a refund warranted?")]
)
print(result.answers["refund"] as Any)
```

For standalone packages, import `SwiftAI` and `SwiftAILiquid`. Pass `LiquidProviderSettings` to configure an explicit key, an asynchronous key supplier, the base URL, headers, or a custom transport.

## Evidence and question limits

Liquid supports `d1.2`, `d1.2-ultra`, and custom model IDs. A request accepts 1 to 128 questions, and each question needs instructions. Choice questions accept 2 to 255 options. Score questions accept 2 to 10 non-null rubric levels. Boolean questions accept optional true and false descriptions.

Use JPEG, PNG or WebP for images and WAV, MP3, FLAC or Ogg for audio. Liquid accepts up to eight images and eight audio clips. A request with a box question requires exactly one image. Text and JSON can accompany media. Direct `doDecide` calls accept media bytes or base64. `AI.experimentalDecide` can download URL evidence before the call.

## Answers and costs

A box answer contains normalized top, bottom, left and right edges. The model returns a refusal when Liquid supplies no box, and the high-level decision operation reports a decision refusal error.

Read costs, confidence per question, score legends and box detection probabilities from `providerMetadata["liquid"]`. The result includes token usage when available and preserves the response headers and body. Liquid reports warnings for reasoning, output token limits and Liquid provider options.
