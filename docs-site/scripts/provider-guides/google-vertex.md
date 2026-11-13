## Current reviewed behavior

The reviewed baseline is `@ai-sdk/google-vertex` 5.0.140. Gemini 4 Carbon uses the shared Gemini request behavior, and Claude Fable 5.2 uses the existing Anthropic hosting policy. Model identifiers remain open strings.

Tool-result files use the caller-configured download transport without Express Mode API keys. MaaS image downloads and every redirect are validated without cloud bearer tokens or provider headers. Abort signals reach downloads and prevent preaborted work before network I/O. Shared native transport tests cover these guarantees; JavaScript Node/edge browser fallback differences remain platform-specific. No browser or live-service parity is claimed.

## Current Vertex behavior

Vertex inherits the Google structured JSON plus function-tool handling, error/denial envelopes and incremental JSON response parsing. Generic embedding dimensions are forwarded when provider-specific output dimensions are absent. `nano-banana-2.1` selects the generateContent image path and preserves binary or `gs://` image inputs, `IMAGE` response modality, typed aspect ratio and provider `imageConfig`, and returned usage/metadata. Masks and multiple image inputs are rejected. Future model IDs remain open strings. Vertex's Anthropic adapter recognizes the published Haiku 5.5 model family through its shared native implementation.

## Gemini long decode

Vertex Gemini shares GenerateContent automatic `CONTINUATION` handling with the Google provider, including appended content, one stream lifecycle, summed billing usage and modality details, and the first request's `initialPromptTokenCount` metadata. `MAX_TOKENS` and failed streaming continuation expose a resumable `continuationToken` under `providerMetadata["google"]`; pass it using the supported `vertex`, `googleVertex`, or `google` provider-options namespace with the original prompt and a larger `maxOutputTokens`.

Automatically continued calls also expose `groundingMetadataPerRequest` under `providerMetadata["google"]`, preserving grounding from each successful request in order and `null` for requests without it. Generation's existing `groundingMetadata` reflects the final response; streaming retains the latest non-null payload. Calls without automatic continuation omit the per-request array.

Explicit thinking budgets or levels override shared reasoning settings. Dotted routed Gemini IDs retain their model capabilities, and Interactions model requests with `background: true` poll until terminal.

## Rotating Express keys and video preprocessing

`GoogleVertexProviderSettings.apiKeyProvider` enables Express Mode with an async
throwing supplier, resolved immediately before each request. The returned key
must be nonempty. Express authentication sets `x-goog-api-key` after custom
headers, matching the provider's request policy. OAuth and service-account modes
retain their existing configuration; tuned endpoints and Interactions still
require standard Google Cloud credentials. Hosted Anthropic/MaaS/xAI adapters
also accept `GoogleVertexHostedProviderSettings.apiKeyProvider` for rotating
bearer credentials.

Gemini file parts forward validated video `startOffset`, `endOffset` and `fps`
metadata. Vertex prefers the `googleVertex` then `vertex` part-metadata namespace
and accepts `google` as a fallback. `GoogleVideoMetadata.jsonValue` supplies the
same typed payload as the Google provider. Frame rates must be greater than
zero and at most 24. Gemini 2.5 Pro's shared reasoning minimum is 128 tokens;
Gemini 3 uses its lowest supported level and reports a compatibility warning
when `none` cannot disable thinking.

For Anthropic-hosted JSON output, see the hosted Anthropic guide for automatic
opt-in, explicit output-format selection and forced-tool fallback rules. Native
service support also depends on the Google Cloud organization policy.

## Gemini unary and Live transcription

`transcriptionModel("gemini-3.5-transcribe")` uses generateContent inline audio.
Other families retain Cloud Speech routing. Options select the first present
`googleVertex`, `vertex`, then `google` namespace. Shared word-timing requests
set `wordTimestamp` unless explicitly disabled; valid timings populate `words`
and existing segments. Unsupported segment requests and missing requested word
timings warn, while usage and raw transcription metadata remain available.

`streamingTranscriptionModel("gemini-3.5-transcribe-live")` uses regional OAuth
WebSockets with project/location and 16 kHz PCM. Express Mode keys do not
support this route. Audio waits for setupComplete; interim text may be revised
before final segments. Cancellation closes input and socket; a resettable
three-second quiet grace handles servers omitting a terminal signal.
`GoogleVertexProvider` accepts injected `webSocketTransport` through an additive
overload; its original initializer/function reference is retained.
