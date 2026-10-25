## Structured JSON with application tools

A request with `.json(schema: ...)` and function tools can return JSON while retaining real application tool calls. Pre-Gemini 3 and forced-tool cases use a collision-safe synthetic response tool. Its arguments become JSON text/stream deltas; its internal tool call and unrelated prose are omitted. Gemini 3 automatic selection uses native JSON output. Reasoning, signatures and application tool calls remain available.

Tool failures and denials use `functionResponse.error`. Generic embedding dimensions apply unless provider-specific output dimensions override them. `nano-banana-2.1` uses the generateContent image route; retrieved-context custom metadata stays in provider metadata.

`decisionModel(...)` uses `DecisionLanguageModel`; see [Decision](../../core/decide/). Batch downloads use the configurable per-row limit.

Gemini image requests merge the typed aspect ratio with provider `imageConfig`; configuring output settings does not discard the caller’s ratio.

## Gemini 4 long decode

GenerateContent automatically follows `CONTINUATION` responses for `gemini-4-argon` and other compatible model IDs. Each hop resends the original request with the returned token, keeps `maxOutputTokens` cumulative, and appends newly generated content. Streams retain one text lifecycle across hops. Usage totals and modality details sum all requests to match billing; `providerMetadata["google"]["initialPromptTokenCount"]` retains the first prompt's count for context-window checks.

After automatic continuation, `providerMetadata["google"]["groundingMetadataPerRequest"]` contains one grounding payload per successful request, in order, with `null` where that request returned none. This preserves earlier search evidence even when the final response has no grounding. The existing `groundingMetadata` field contains the final response's payload for generation and the latest non-null payload for streaming. Single-request calls, including manual resume calls that do not continue automatically, omit the per-request array.

A response ending with `MAX_TOKENS` exposes `providerMetadata["google"]["continuationToken"]`. Resume with the original prompt, a larger `maxOutputTokens`, and that token in `providerOptions["google"]["continuationToken"]`. Failed streaming continuation emits an error followed by finish metadata containing the resumable token. Cancellation propagates through every hop.

`responseModalities` accepts `AUDIO` alongside `TEXT` and `IMAGE`. Explicit `thinkingConfig.thinkingBudget` or `thinkingConfig.thinkingLevel` takes precedence over the shared `reasoning` setting. Gemini 3+ Pro models normalize `none` and `minimal` reasoning to their supported `low` floor. Routed IDs such as `eu.gemini-2.5-flash` retain the correct model capabilities. Interactions model calls with `background: true` poll until terminal, including Gemini 4 long decode.
## Continuation and streamed tool arguments

Each successful automatic continuation starts with a fresh completion state;
an empty next response remains interrupted instead of inheriting the previous
finish reason. A failed continuation retains the preceding response's state.
Partial function arguments, including response tools, preserve nested empty
arrays and objects and produce valid concatenated JSON deltas. Legacy tool-call
snapshot parts remain available alongside the incremental tool-input lifecycle.
