## Quick start

```swift
import SwiftAISDK

let typeSafe = AIProviders.typeSafeAI()
let result = try await AI.experimentalDecide(
    model: try typeSafe.decisionModel("jev-latest"),
    state: .text("The export crashes in Safari."),
    questions: [
        "bug": .boolean(instructions: "Does the user report broken functionality?"),
        "severity": .score(criteria: ["Cosmetic", "Degraded", "Blocking"])
    ]
)
print(result.answers)
```

For the modular packages, use `import SwiftAI` and `import SwiftAITypeSafeAI`, then
`AIProviders.typeSafeAI(configuration: TypeSafeAIProviderSettings(...))`. The native
factory requires a configuration argument and does not throw; `typeSafeAI` is a
default provider instance.

The API key is resolved when a request is made, not when the provider is created, so a
key can be installed in the environment later. `TypeSafeAIProviderSettings(environment:)`
supplies a custom environment map.

## Decisions

Decisions call `/systemone` with Choice, Score, Boolean and Box questions. Choice
questions take 1–255 options and Score questions 1–10 non-null levels. Answers are
rounded to two decimals, which the result reports as its rounding. Confidence values
and score legends (keyed by question ID) are under `providerMetadata.typesafe`.
`maxOutputTokens`, `reasoning` and unknown provider options produce warnings; known
options are validated before the request. See [Decisions](../../core/decide/).

A state made of a single JSON string, object or array is sent as-is. Other states,
including JSON null, Boolean and number values, are joined into text.

## Images and Box questions

State may include PNG or JPEG images as inline data or base64. Images are uploaded as
multipart parts next to `request.json`; text-only decisions stay JSON. A `.box`
question locates an object and returns `AIDecisionBox` edges (`top`, `bottom`, `left`,
`right`) in 0–1, with `left < right` and `top < bottom`. Box instructions may be
omitted.

```swift
let result = try await AI.experimentalDecide(
    model: try typeSafe.decisionModel("jev-latest"),
    state: .parts([.file(
        mediaType: "image/png", data: .data(imageBytes),
        providerOptions: TypeSafeAIFilePartProviderOptions(reference: "[photo]").providerOptions
    )]),
    questions: ["object": .box(instructions: "The mug in [photo]")],
    providerOptions: TypeSafeAIDecisionModelOptions(longContext: true).providerOptions
)
```

`TypeSafeAIFilePartProviderOptions` sets each image's reference, which must be
nonempty and unique. By default the SDK inserts the reference (or a generated one) into
the state text unless the state already mentions it. `insertReference: false` requires
an explicit reference that you use in instructions or criteria.

Images or Box questions send TypeSafe's experimental image header.
`TypeSafeAIDecisionModelOptions(longContext: true)` sends the separate 262k-token
long-context header; TypeSafe documents this mode as slower and less accurate.

## Evaluation API

`evaluationModel(_:)` and `AI.experimentalEvaluate` remain available for existing code
and use the same `/systemone` endpoint with the stricter Evaluation question contract.
New code should use decisions.

## Rotating credentials

`TypeSafeAIProviderSettings.apiKeyProvider` accepts an async throwing closure resolved
before each authenticated request. A supplier failure stops the request before it is
sent.
