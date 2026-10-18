## Current Vertex behavior

Vertex inherits the Google structured JSON plus function-tool handling, error/denial envelopes and incremental JSON response parsing. Generic embedding dimensions are forwarded when provider-specific output dimensions are absent. `nano-banana-2.1` selects the generateContent image path and preserves binary or `gs://` image inputs, `IMAGE` response modality, typed aspect ratio and provider `imageConfig`, and returned usage/metadata. Masks and multiple image inputs are rejected. Future model IDs remain open strings. Vertex's Anthropic adapter recognizes the published Haiku 5.5 model family through its shared native implementation.

## Gemini long decode

Vertex Gemini shares GenerateContent automatic `CONTINUATION` handling with the Google provider, including appended content, one stream lifecycle, summed billing usage and modality details, and the first request's `initialPromptTokenCount` metadata. `MAX_TOKENS` and failed streaming continuation expose a resumable `continuationToken` under `providerMetadata["google"]`; pass it using the supported `vertex`, `googleVertex`, or `google` provider-options namespace with the original prompt and a larger `maxOutputTokens`.

Explicit thinking budgets or levels override shared reasoning settings. Dotted routed Gemini IDs retain their model capabilities, and Interactions model requests with `background: true` poll until terminal.
