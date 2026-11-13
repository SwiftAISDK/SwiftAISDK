## Current reviewed behavior

The reviewed baseline is `@ai-sdk/google` 4.0.120. `decisionModel("gemini-decision-1")` uses the native `/decisions` endpoint for Choice, Score and Boolean questions. Safety-blocked input returns refusals. Ordered text, JSON, inline media and media URLs are preserved; Box and provider file references are rejected before HTTP.

For source and behavior compatibility, existing non-`gemini-decision-*` IDs passed to `decisionModel` retain the Swift structured-generation adapter, including Box. Use `nativeDecisionModel("custom-decision-id")` to opt any custom or future ID into the native endpoint. This explicit routing differs from the current JavaScript factory, which routes all decision IDs natively. Existing `evaluationModel` semantics are also preserved.

Typed extraction is a distinct contract:

```swift
let extraction = try provider.extractionModel("gemini-3.8-flash")
let result = try await extraction.doExtract(.init(
    state: [.text("The invoice total is 42 EUR.")],
    fields: ["total": .init(type: .number, instructions: "Invoice total", unit: "EUR")]
))
```

Gemini 4 Hydrogen accepts portable and explicit `xhigh` thinking with a `low` minimum. Service-tier metadata falls back to `x-gemini-service-tier` when usage omits the value. Streaming document sources deduplicate by full resource URI, and File Search sources by store and title. Dotted array indexes obey the same contiguous bounds and string continuation as bracket indexes. Vertex shares these request/response algorithms.

## Structured JSON with application tools

A request with `.json(schema: ...)` and function tools can return JSON while retaining real application tool calls. Pre-Gemini 3 and forced-tool cases use a collision-safe synthetic response tool. Its arguments become JSON text/stream deltas; its internal tool call and unrelated prose are omitted. Gemini 3 automatic selection uses native JSON output. Reasoning, signatures and application tool calls remain available.

Tool failures and denials use `functionResponse.error`. Generic embedding dimensions apply unless provider-specific output dimensions override them. `nano-banana-2.1` uses the generateContent image route; retrieved-context custom metadata stays in provider metadata.

For non-`gemini-decision-*` IDs, `decisionModel(...)` retains `DecisionLanguageModel`; see [Decision](../../core/decide/). Batch downloads use the configurable per-row limit.

Gemini image requests merge the typed aspect ratio with provider `imageConfig`; configuring output settings does not discard the caller’s ratio.

## Grounding across continued generation

GenerateContent automatic continuation preserves search evidence under `providerMetadata["google"]["groundingMetadataPerRequest"]`: one entry per successful request, in order, with `null` for requests without grounding. Generation keeps the final response's grounding in `groundingMetadata`; streaming keeps the latest non-null grounding there. Calls without automatic continuation omit the per-request array. See the [Google Generative AI guide](../google-generative-ai/) for continuation and resume behavior.

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
