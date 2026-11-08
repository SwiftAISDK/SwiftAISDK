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

## Per-request credentials and video preprocessing

`GoogleProviderSettings.apiKeyProvider` accepts an async throwing key supplier.
It is called before each authenticated HTTP request, including continued
GenerateContent calls, batch operations, file-upload initiation and processing
polls. Static `apiKey` settings remain supported. Custom provider and request
headers retain precedence; unauthenticated upload URLs receive no API key.

User file parts accept `videoMetadata` under their `google` provider metadata.
The typed `GoogleVideoMetadata` value exposes `startOffset`, `endOffset` and `fps`
through `jsonValue`. Offsets are duration strings such as `"3.5s"`; frame rate
must be greater than zero and at most 24. Set the value on inline files or
hosted/provider references using
`providerMetadata: ["google": ["videoMetadata": clip.jsonValue]]`.
The `googleVertex` and `vertex` namespaces are accepted as fallbacks.

Gemini 3 reasoning that cannot disable thinking maps `none` to its lowest
supported effort with a compatibility warning. Gemini 2.5 Pro maps it to the
minimum 128-token budget; models that support disabled thinking still send zero.
Continued streamed function strings close on their final chunk, including an
empty chunk or explicit terminator, so accumulated JSON becomes valid promptly.

## Native realtime and current request behavior

`GoogleGenerativeAIProvider.realtimeModel("gemini-3.8-live")` implements native
Gemini Live WebSockets with ephemeral client secrets or trusted server API-key
headers. Use `AIRealtimeSession.connectServer` for lifecycle ownership and an
injected duplex transport. Async credentials resolve before connecting;
conversation intent is supported and transcription intent rejects before I/O.
Each session has its own parser. `generationComplete` does not end a turn; late
output transcripts retain its ID. `event.usage` preserves same-frame totals and
known modality counts; unrelated snapshots are not summed or attached to later
completions. Browser capture/playback and standalone Google transcription/speech
translation remain separate native gaps.

GenerateContent retains ordered text/function calls, signed empty thought blocks
and parsed tool input strings. Sparse/overflowing streamed array indexes are
rejected without allocating holes. RPC status strings preserve raw errors and
supply retryability. Provider tool NONE filtering precedes JSON fallback;
Interactions maps string labels and current function/provider tools. Speech
forwards explicit languageCode for single/multiple voices, omitting auto.
