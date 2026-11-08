## Images and Box decisions

Use [`AI.experimentalDecide`](../../core/decide/) with `decisionModel("jev-preview")`
and `.box(instructions:)` to locate an object in PNG/JPEG evidence. Answers use
`AIDecisionBox(top:bottom:left:right:)` with ordered finite edges in [0, 1].

`TypeSafeAIFilePartProviderOptions` supplies nonempty unique references and optional
`insertReference`. Images are uploaded as multipart files alongside `request.json`;
text-only decisions remain JSON. The SDK adds the experimental images header for
images or Box questions and enables the 262k-token long-context header only when
`TypeSafeAIDecisionModelOptions(longContext: true)` is supplied. Unknown model
options still warn; known options are validated before I/O. See the Decision guide
for a complete typed example and reference insertion rules.

## Rotating API keys

`TypeSafeAIProviderSettings.apiKeyProvider` resolves a fresh key before
each authenticated request; static `apiKey` settings remain supported. Supplier
errors stop the request before it reaches the transport.

## Current decision limits and state

Decision Choice questions require 1...255 options, and Score questions
require 1...10 non-null levels. Structured score legends are retained in
`providerMetadata.typesafe.legend` keyed by question ID. A single JSON string,
object or array state is forwarded directly; null, Boolean and number states are
serialized as text. The high-level legacy Evaluation API keeps its existing
stricter question contract.

Decision `.box()` may omit instructions, represented as JSON null. Box questions
enable the image feature header even without image assets. Missing/null score
legends produce an empty root legend map; a non-object legend is invalid.
