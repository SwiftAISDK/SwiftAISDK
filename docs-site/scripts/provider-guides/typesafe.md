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
