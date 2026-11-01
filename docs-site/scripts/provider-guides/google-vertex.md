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

For Anthropic-hosted JSON output, schemas supported by native structured output
use `output_config.format` on Claude Sonnet 5.5, Opus 5.5 and Fable 5.1, which
reject forced tool selection. Other hosted Claude families retain the JSON
response-tool fallback. Recursive or otherwise unsupported schemas retain that
fallback too; automatic tool selection is used when the model rejects forcing.
