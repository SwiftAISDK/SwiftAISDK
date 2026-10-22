## Structured JSON with application tools

A request with `.json(schema: ...)` and function tools can return JSON while retaining real application tool calls. Pre-Gemini 3 and forced-tool cases use a collision-safe synthetic response tool. Its arguments become JSON text/stream deltas; its internal tool call and unrelated prose are omitted. Gemini 3 automatic selection uses native JSON output. Reasoning, signatures and application tool calls remain available.

Tool failures and denials use `functionResponse.error`. Generic embedding dimensions apply unless provider-specific output dimensions override them. `nano-banana-2.1` uses the generateContent image route; retrieved-context custom metadata stays in provider metadata.

`decisionModel(...)` uses `DecisionLanguageModel`; see [Decision](../../core/decide/). Batch downloads use the configurable per-row limit.

Gemini image requests merge the typed aspect ratio with provider `imageConfig`; configuring output settings does not discard the caller’s ratio.

## Grounding across continued generation

GenerateContent automatic continuation preserves search evidence under `providerMetadata["google"]["groundingMetadataPerRequest"]`: one entry per successful request, in order, with `null` for requests without grounding. Generation keeps the final response's grounding in `groundingMetadata`; streaming keeps the latest non-null grounding there. Calls without automatic continuation omit the per-request array. See the [Google Generative AI guide](../google-generative-ai/) for continuation and resume behavior.
