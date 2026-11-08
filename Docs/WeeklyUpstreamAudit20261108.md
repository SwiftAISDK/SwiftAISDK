# Weekly upstream audit - 2026-11-08

Status: source review and portable implementation in progress; final integration and publication gates remain pending. No release is claimed by this draft.

Fresh npm metadata covers **54 tracked packages**, with **52 version changes**. Scoped search returned **76 names**; exact registry-prefix enumeration returned **93**. The sole new model provider is **`@ai-sdk/parallel@3.0.4`**, proposed separately below. All 52 old/new comparisons use **104 integrity-verified archives** and exact matching-release tests; no fallback snapshot is promoted to release evidence.

[Structured package evidence](WeeklyUpstreamAudit20261108.json) records source/declaration/test dispositions, archive hashes, immutable refs, translated tests and retained gaps. The refreshed [test inventory](UpstreamTestInventory.md) contains 1,180 executable paths at `0f3a85f92d1ce06ccde01d662407ef83e097a712`; it remains separate from matching-release evidence.

## Tracked npm packages

| Package | Reference | Latest | Native decision |
| --- | --- | --- | --- |
| `@ai-sdk/alibaba` | `2.0.80` | `2.0.85` | Published catalog extraction preserves Qwen JSON-schema prefixes, preserved-thinking exact IDs, embedding limit10/parallel false, and legacy/Wan2.7/Wan3 routing. These native policies already exist; no wire parser/options/errors/stream change in this delta. Internal catalogs are not exported from the provider entry point. Advance reviewed provenance and matching request user-agent only. |
| `@ai-sdk/amazon-bedrock` | `5.0.130` | `5.0.135` | Explicit Claude5/5.5 support for native output/strict tools matches the published catalog; unsupported future aliases and suffix boundaries remain conservative. Auto native output checks schema preservation; JSON-tool fallback filters application tools using the caller choice. Anthropic named choices retain all function tools and default to disabled parallel use. Explicit false opts out; other/rejecting models receive only... |
| `@ai-sdk/anthropic` | `4.0.94` | `4.0.99` | Message threads: create/continue wire mapping, retained local tool/name state, omitted leading system/tools on continuation, fixed beta-set warnings, top-level cache breakpoint accounting, compaction/context restrictions and batch rejection. Inline function/provider additions: stable unary/stream definitions, alias mapping with declared reverse-name precedence, automatic beta headers, computer-tool warnings, caller... |
| `@ai-sdk/anthropic-aws` | `2.0.87` | `2.0.92` | Shared Anthropic config explicitly opts Claude Platform on AWS into message threads. Canonical Anthropic provider options remain accepted. Published catalog aliases reuse Anthropic internal metadata without changing the Swift public catalog API or AWS authentication, signing, workspace headers, transport, errors or streaming behavior. |
| `@ai-sdk/assemblyai` | `3.0.72` | `3.0.77` | Flat error strings and existing nested error messages use the provider error path on all three HTTP stages. |
| `@ai-sdk/azure` | `4.0.114` | `4.0.119` | Azure Chat/Completion and OpenAI image/speech/transcription accept OpenAI options in azure; merge openai then azure so azure wins, retaining other openai keys. Strip routing/Speech/MAI-only controls from delegated OpenAI bodies and emit appropriate unsupported warnings. Azure Responses uses first-present azure namespace as a whole, with openai fallback only when azure is absent/null; this preserves published... |
| `@ai-sdk/baseten` | `2.1.60` | `2.1.65` | Transform only the exact affected serverless model and JSON formats; prepend a separate system instruction and return a compatibility warning. Independent paired generate/stream tests exposed dropped reasoning and provider options. Baseten now uses its inherited generic compatible option path, including camelCase and raw reasoning_effort none. Dedicated deployments, other models, text requests and disabled reasoning... |
| `@ai-sdk/black-forest-labs` | `2.0.74` | `2.0.79` | Missing/null polling_url selects configured /get_result with encoded id. Task not found is retried only for the fallback, including HTTP 404 bodies, up to 20 occurrences within deadline and abort controls. Independent review rejects a non-string/non-null polling_url instead of treating malformed data as absent. |
| `@ai-sdk/bytedance` | `2.0.75` | `2.0.80` | Parameterize the existing submit/poll regression with seed 0 and 11 and assert the actual submitted seed. Retain the existing ai-sdk/bytedance/2.0.71 suffix: upstream does not attach its own versioned suffix, so an npm baseline change does not justify runtime release. |
| `@ai-sdk/cartesia` | `3.0.67` | `3.0.71` | Validate volume/emotion/locale/normalization/pronunciationDictionaryId and combine volume/emotion with effective speed. Locale overrides generic language with warning and conflicts with provider language. Validate max 100 string keyterms, finite numeric turn thresholds and integer timeout; encode repeated keyterm query values and omit/warn thresholds when detection is disabled. |
| `@ai-sdk/cerebras` | `3.0.82` | `3.0.87` | Validate only queueThreshold in the native cerebras dynamic namespace; integer 50...20000 wins caller/provider header casing without mutation. Remove queueThreshold from JSON and map serviceTier to service_tier. Expose the last non-null returned service tier and preserve other metadata. Independently port the inherited compatible actual request URL metadata and refusal content/finish semantics through the bespoke native... |
| `@ai-sdk/cohere` | `4.0.73` | `4.0.78` | Choose the first document-bearing source; preserve all citation sources and custom document fields; skip tool-only citations. Emit sources for single/array citation-start payloads and allocate distinct request-scoped IDs. Prefer v2 response id, tolerate missing/empty token usage, never substitute billed units for tokens. Preserve valid raw JSON arguments; quote malformed text. Native null tool input already normalizes to {}. |
| `@ai-sdk/deepgram` | `3.1.43` | `3.1.48` | ported-native-delta-with-documented-adaptations |
| `@ai-sdk/deepinfra` | `3.0.82` | `3.0.87` | Internal language/image catalog extraction preserves JSON Schema forwarding, image-input allowlist and one image per call. No declaration or changed-test delta. Existing compatible language engine consumes its own verified changes; owning provider code only updates upstream user-agent. |
| `@ai-sdk/deepseek` | `3.0.77` | `3.0.81` | Valid JSON argument strings pass unchanged; malformed raw text is JSON quoted. Independent review preserves unknown strict-tool capability for azure.* adapters, forwarding per-tool true/false/omitted choices without native beta/mixed-strict enforcement. Native DeepSeek beta and non-beta strict policies remain explicit and unchanged. |
| `@ai-sdk/elevenlabs` | `3.0.76` | `3.0.81` | Nonnull sourceUrl appends source_url and omits file; nonempty supplied audio emits one warning. Nil/null retains file upload and existing option defaults. |
| `@ai-sdk/fal` | `3.0.73` | `3.0.78` | Parameterize async submission regression for seeds 0/42; independently add actual request-body assertion. Keep native model normalization, file/mask capability lists and image limit equivalent to internal catalog extraction. Update user-agent literal to reviewed published version 3.0.78. |
| `@ai-sdk/fish-audio` | `3.0.50` | `3.0.54` | Published sources, public declarations and exact-release tests unchanged. Published package metadata/dependency/bundle version refresh only. Update native versioned request user-agent; no new media/lifecycle API is introduced. |
| `@ai-sdk/fireworks` | `3.0.85` | `3.0.90` | Internal catalog refactor retains backend routes, file/mask/size policies, one image per call and exact reasoning family maps (gpt-oss/glm-5p3/muse-spark exclude none, nemotron/inkling exclude minimal). Literal readonly maxImagesPerCall becomes getter in declarations; native computed behavior already matches. No changed release tests; request user-agent updated. |
| `@ai-sdk/gateway` | `4.0.132` | `4.0.138` | ported-native-deltas-with-explicit-adaptations |
| `@ai-sdk/gmicloud` | `3.0.53` | `3.0.58` | Adds an internal descriptive model catalog without provider/index wiring or declaration/test changes. No native request, parser, auth, error, stream or telemetry behavior changes. Update request user-agent and reviewed metadata; catalog is not a new public product API. |
| `@ai-sdk/gladia` | `3.0.72` | `3.0.77` | ported-native-delta-with-documented-adaptations |
| `@ai-sdk/google` | `4.0.109` | `4.0.114` | ported-native-deltas-with-explicit-adaptations |
| `@ai-sdk/google-vertex` | `5.0.129` | `5.0.134` | ported-native-deltas-with-explicit-adaptations |
| `@ai-sdk/groq` | `4.0.74` | `4.0.78` | HTTP(S) URL without userinfo becomes multipart url, strips fragment without mutation and avoids local upload/download. Return nil only for HTTP400 failed-to-retrieve-media redirect status301/302/303/307/308; other errors propagate. Plain-text response path is shared by file and URL input. Valid raw tool JSON is preserved, malformed raw text is quoted. |
| `@ai-sdk/heygen` | `3.0.14` | `3.0.19` | Adds an internal descriptive model catalog only; published factory/polling/download behavior, declarations and exact-release tests unchanged. Preserve native persisted async video adapter and update versioned request user-agent. |
| `@ai-sdk/huggingface` | `2.0.82` | `2.0.87` | Internal descriptive catalog only; published entry point, declarations, release tests and request/response behavior unchanged. No upstream versioned user-agent exists. Preserve the existing native ai-sdk/huggingface/2.0.82 header adaptation instead of creating a runtime change solely for npm drift. Advance reviewed baseline, no owning distribution release. |
| `@ai-sdk/hume` | `3.0.72` | `3.0.76` | No published source/public declaration/exact-release test changes. Dependency/bundle version metadata only. Refresh versioned request user-agent; preserve native speech behavior. |
| `@ai-sdk/klingai` | `4.0.74` | `4.0.79` | Exercise unsupported seed 0 and assert seed is omitted with warning. Retain mode detection/API model name derivation and update reviewed versioned user agent4.0.79. |
| `@ai-sdk/lmnt` | `3.0.36` | `3.0.36` | Current; no drift. |
| `@ai-sdk/luma` | `3.0.73` | `3.0.78` | Image capability constants move to an internal catalog with the same one-image limit, photon input-file support and no mask support. Existing native image behavior matches; no declaration/test delta. Update request user-agent. The pre-existing lack of native Luma video remains separate from this image/version delta. |
| `@ai-sdk/mcp` | `2.0.88` | `2.0.93` | Canonical URL strips fragment, keeps query and normalizes an empty root path. Custom nil validation falls back to it. Unbound refresh tokens must be invalidated and reread before DCR saves credentials; original binding is checked before registration. Independent review added explicit HTTPS-to-HTTP discovery rejection before the next request and for transport-reported final URLs. |
| `@ai-sdk/minimax` | `3.0.71` | `3.0.76` | New MiniMaxLanguageModelOptions.ServiceTier plus source-compatible initializer default; typed values map through the existing Anthropic Messages adapter. MiniMax namespace overrides Anthropic values. Known foreign tiers warn/omit; invalid/null tiers reject before network. Streaming and unary requests share policy. New internal model catalogs extract existing M3.1 numeric parsing, video resolution/default/reference/duration... |
| `@ai-sdk/mistral` | `4.0.77` | `4.0.81` | ported-native-delta-with-documented-adaptations |
| `@ai-sdk/moonshotai` | `3.0.82` | `3.0.87` | Internal catalog extraction preserves exact Kimi families, temperature/reasoning/tool-required policy and all-ID structured outputs, including unknown future IDs. No declaration or test delta. Native owning wrapper retains those rules; refresh user-agent. |
| `@ai-sdk/open-responses` | `2.0.77` | `2.0.82` | Published response.created now emits server id/timestamp/model metadata. Native shared Responses engine already did so before this pass; focused translated regression verifies server metadata overrides requested model ID. New internal arbitrary-backend model catalog/provider option descriptions remain internal and do not imply known support or runtime validation. Published user-agent literal advanced from 2.0.77 to 2.0.82;... |
| `@ai-sdk/openai` | `4.0.106` | `4.0.111` | Chat: preserve content and refusal as ordered text; stop plus refusal maps to content-filter while client tool calls retain priority; unary and all streamed content/refusal logprobs are retained in emission order, including explicit empty lists. Chat: parse message-level openai.name; preserve it on system/developer/user/assistant messages, reject invalid values before transport, warn and omit it on tool messages;... |
| `@ai-sdk/openai-compatible` | `3.0.82` | `3.0.87` | Generic Chat: preserve string refusals (ignore non-string refusal), append them after content, map stop+refusal to content-filter, retain tool and error precedence in unary/incremental streams. Generic replay: preserve valid pre-serialized tool JSON and JSON-quote malformed strings; JSONValue has neither BigInt nor reference cycles. OpenAI-specific malformed-arguments-to-object behavior is kept distinct. Generic inline... |
| `@ai-sdk/perplexity` | `5.0.24` | `5.0.28` | Omit native/function tool definitions, skip warnings for disabled provider tools and override max_tool_calls with 0. Preserve conversation tool-call/result history. |
| `@ai-sdk/prodia` | `2.0.73` | `2.0.78` | Internal catalog extraction preserves maxImages1, no file or mask inputs; new catalog includes descriptions of existing upstream capabilities. Public declarations/tests unchanged. Native unary/simulated language and existing media behavior remain; update versioned user-agent. |
| `@ai-sdk/quiverai` | `2.0.73` | `2.0.78` | Published source/declaration/exact-release tests unchanged; package dependency/bundle version refresh only. Native request user-agent advances; existing custom reasoning mapping unchanged. |
| `@ai-sdk/replicate` | `3.0.73` | `3.0.78` | Detached cancel uses configured /predictions/encoded-id/cancel, fresh provider credentials, no per-call headers/abort signal or response cancel URL. Cancellation failures cannot replace or delay original abort/timeout failures. Prediction id is required. Independently added original-failure/fresh-credential/custom-endpoint and seed 0/42 regressions. |
| `@ai-sdk/revai` | `3.0.72` | `3.0.76` | Published source/declaration/exact-release tests unchanged; dependency/bundle refresh only. Update native versioned request user-agent; existing upload/poll behavior remains. |
| `@ai-sdk/togetherai` | `3.0.83` | `3.0.88` | Internal catalogs retain exact DeepSeek-V4-Flash-0731 JSON-schema support, image-file allowlists, non-diffusion Gemini exception and one-image calls. No changed declarations or release tests. Preserve native policies and refresh versioned user-agent. |
| `@ai-sdk/topaz` | `3.0.19` | `3.0.23` | Retain validated upload target/trusted configured origin and redirect-disabled PUT with no API key. Independently extend cleanup fixture to both 307/308 and assert exactly one PUT before DELETE. Update reviewed versioned user agent3.0.23. |
| `@ai-sdk/typesafe-ai` | `3.0.31` | `3.0.35` | Preserve JSON object/array/string state and turn primitive JSON into textual state. Require 1...255 choice options and 1...10 nonnull score levels. Preserve structured score legends by question ID under provider metadata; missing/null legends produce empty root legend map. Allow .box() native null instructions and enable images header without image assets. |
| `@ai-sdk/vercel` | `3.0.30` | `3.0.30` | Current; no drift. |
| `@ai-sdk/voyage` | `2.0.72` | `2.0.77` | Internal catalog extraction preserves embeddings limit128, parallel support, embedding options and reranking behavior. No changed declarations/tests. Native implementation already enforces limits; update versioned request user-agent. |
| `@ai-sdk/xai` | `5.0.35` | `5.0.40` | Responses unary finish classification now reads incomplete_details.reason before status and preserves client-side tool-call priority through the existing configurable shared engine. Realtime declares native server-WebSocket capability, builds server URL from configured base path with http->ws/https->wss and encoded model, resolves async credentials freshly; unsupported transcription intents fail before... |
| `@ai-sdk/zai` | `3.0.44` | `3.0.49` | New internal descriptive model catalog is not publicly exported or wired to request builders. No declaration, parser, error, streaming or changed-test behavior delta. Preserve owning native ZAI chat policy and refresh user-agent. |
| `ai` | `7.0.159` | `7.0.165` | Queue user messages one completed task at a time, behind immediate steering and not after truncation; preserve shared idempotent receipt semantics and stream delivered IDs/messages before receiving step output. Persist native UI steering parts, validate user-only content and replay assistant/tool/user ordering while retaining text/file metadata and references. Sanitize provider request URLs to HTTP origins across... |
| `@ai-sdk/provider` | `4.0.35` | `4.0.37` | Add optional request URL metadata, ping and delivered-steering stream parts in the native unified stream contract. Add optional shared transcription timestamp granularities/word timings and a default-declining native URL hook so existing model conformances remain valid. Add video/reranking/decision descriptive capability sections with Codable support and caller-storage video delivery descriptors. Permit omitted/null... |
| `@ai-sdk/provider-utils` | `5.0.72` | `5.0.76` | Reject HTTPS to HTTP download redirects before sending another request (buffered and streaming paths), preserving existing private-target validation. Add native resolveProviderOptions first/merge resolution with per-namespace validation, deduplication and exact contributing namespace tracking. Extend tool name mapping with deterministic duplicate forward aliases and explicit preferred reverse names for Anthropic inline... |
| `@ai-sdk/react` | `4.0.163` | `4.0.169` | Published delta only adds provider-owned browser transport endpoint selection to useRealtime. Native UI has no React hook or browser MediaStream ownership API. The upstream ai UI steering delta is translated in SwiftAIUI and separately released for that concrete behavior. |

## New provider proposal

Next proposed port: independent swift-ai-parallel provider with authenticated /v1/decisions, fast/custom model factory, text/JSON state, boolean/choice/score validation, includeExcerpts, citations/confidence/decisionId/legend/mode metadata, usage, errors and focused fixtures. No Box or automatic implementation in this weekly pass.

The published API uses `PARALLEL_API_KEY` / `x-api-key`, 1...100 ASCII-named questions, 2...255 Choice options and 2...10 Score levels. Existing text/JSON Decision contracts can host it, with a separate complete provider/test/docs vertical. It is not scaffolded or released here.

## Native adaptations and retained gaps

- All17 old public function/initializer selectors and defaults remain available through forwarding overloads. Existing realtime event associated-value arity is preserved. Exhaustive switches over LanguageStreamPart, AIUIMessagePart, AIRealtimeConnectionKind, AIModelCapabilities.Realtime.Connection and AIModelCapabilitySection must handle the new cases; see Migration.md.
- Native Data/JSONValue semantics do not reproduce JavaScript prototypes, BigInt, cycles, getters or toJSON. The JS binary scanner/low-memory optimization has no matching native product contract.
- Browser media ownership/WebRTC, React hooks, Node tracing, workflow/harness/sandbox adapters and pre-existing provider gaps remain explicit per package.
- Gateway incremental binary image-stream decoding remains deferred; unsupported streaming options are stripped with a warning. Mistral Voice exposes native session control and pure event contracts; browser LiveKit media is not implemented. Separate Google transcription and speech-translation products remain gaps; Vertex Gemini unary and Live transcription are implemented here.
- Native max-step defaults and single-response Anthropic body cancellation remain unchanged.
- Tests use offline mocked/native fixtures. No paid live-service acceptance is claimed.

## Unimplemented namespace inventory

| Package | Latest | Classification |
| --- | --- | --- |
| `@ai-sdk/angular` | `3.0.165` | JavaScript framework/UI product |
| `@ai-sdk/code-mode` | `1.0.122` | independent sandbox/tool product |
| `@ai-sdk/codemod` | `4.0.4` | JavaScript tooling/runtime product |
| `@ai-sdk/devtools` | `1.0.68` | JavaScript tooling/runtime product |
| `@ai-sdk/durable-agent` | `0.0.1` | JavaScript tooling/runtime product |
| `@ai-sdk/harness` | `1.0.176` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-acp` | `1.0.116` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-claude-code` | `1.0.180` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-cline` | `1.0.104` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-codex` | `1.0.178` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-cursor` | `1.0.91` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-deepagents` | `1.0.176` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-fx` | `1.0.92` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-github-copilot` | `1.0.73` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-grok-build` | `1.0.115` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-opencode` | `1.0.179` | JavaScript harness/framework adapter product |
| `@ai-sdk/harness-pi` | `1.0.179` | JavaScript harness/framework adapter product |
| `@ai-sdk/langchain` | `3.0.165` | JavaScript harness/framework adapter product |
| `@ai-sdk/llamaindex` | `3.0.165` | JavaScript harness/framework adapter product |
| `@ai-sdk/otel` | `1.0.165` | JavaScript tooling/runtime product |
| `@ai-sdk/parallel` | `3.0.4` | new native model provider: Decision V4 |
| `@ai-sdk/policy-opa` | `1.0.165` | JavaScript tooling/runtime product |
| `@ai-sdk/rsc` | `3.0.165` | JavaScript framework/UI product |
| `@ai-sdk/sandbox-just-bash` | `1.0.176` | JavaScript tooling/runtime product |
| `@ai-sdk/sandbox-vercel` | `1.0.176` | JavaScript tooling/runtime product |
| `@ai-sdk/solid` | `1.2.13` | JavaScript framework/UI product |
| `@ai-sdk/spacexai` | `0.0.0` | empty seed/reservation |
| `@ai-sdk/specification` | `0.0.0` | empty seed/reservation |
| `@ai-sdk/svelte` | `5.0.165` | JavaScript framework/UI product |
| `@ai-sdk/swarm` | `0.1.39` | JavaScript tooling/runtime product |
| `@ai-sdk/test-server` | `2.0.4` | JavaScript tooling/runtime product |
| `@ai-sdk/tool-bash` | `1.0.19` | independent sandbox/tool product |
| `@ai-sdk/tool-web-fetch` | `1.0.15` | independent sandbox/tool product |
| `@ai-sdk/tools` | `0.0.0` | empty seed/reservation |
| `@ai-sdk/tui` | `1.0.166` | JavaScript tooling/runtime product |
| `@ai-sdk/ui-utils` | `1.2.11` | JavaScript framework/UI product |
| `@ai-sdk/valibot` | `3.0.76` | JavaScript schema adapter |
| `@ai-sdk/vue` | `4.0.165` | JavaScript framework/UI product |
| `@ai-sdk/workflow` | `2.0.97` | JavaScript harness/framework adapter product |
| `@ai-sdk/workflow-harness` | `1.0.176` | JavaScript harness/framework adapter product |

## Verification and release scope

Final local suites, tooling, deterministic exports/minimum ranges, exact canonical source CI, changed-only Swift versions, publication refs, standalone hosted CI and clean public-tag consumers will be recorded after their gates pass. ByteDance, Hugging Face, LMNT and Vercel require no runtime release for a reviewed baseline alone. Shared-core verification does not automatically release unchanged providers.

## Proposed independent Swift release selection

48 changed units:21 minor and27 patch candidates. Four unchanged runtime distributions keep their published versions. Direct minima below change only for concrete new API or required inherited behavior; shared-helper verification still covers all52 packages. Publication refs and validation results follow only after their gates pass.

| Swift package | Previous | Proposed | SemVer | Direct minimum changes |
|---|---|---|---|---|
| `swift-ai-alibaba` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-amazon-bedrock` | 1.1.0 | 1.1.1 | patch | swift-ai-core 1.2.0 → 1.3.0; swift-ai-anthropic 1.2.0 → 1.3.0; swift-ai-openai 1.1.0 → 1.2.0; swift-ai-openai-compatible 1.1.0 → 1.2.0 |
| `swift-ai-anthropic` | 1.2.0 | 1.3.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-anthropic-aws` | 1.1.0 | 1.2.0 | minor | swift-ai-anthropic 1.2.0 → 1.3.0 |
| `swift-ai-assemblyai` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-azure` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0; swift-ai-openai 1.1.0 → 1.2.0; swift-ai-openai-compatible 1.0.0 → 1.2.0; swift-ai-deepseek 1.1.0 → 1.1.1 |
| `swift-ai-baseten` | 1.1.0 | 1.1.1 | patch | swift-ai-openai-compatible 1.0.0 → 1.2.0 |
| `swift-ai-black-forest-labs` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-bytedance` | 1.0.0 | 1.0.0 | none | retained |
| `swift-ai-cartesia` | 1.1.0 | 1.2.0 | minor | retained |
| `swift-ai-cerebras` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0; swift-ai-openai-compatible 1.0.0 → 1.2.0 |
| `swift-ai-cohere` | 1.1.0 | 1.2.0 | minor | retained |
| `swift-ai-core` | 1.2.0 | 1.3.0 | minor | retained |
| `swift-ai-deepgram` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-deepinfra` | 1.1.0 | 1.1.1 | patch | swift-ai-openai-compatible 1.0.0 → 1.2.0 |
| `swift-ai-deepseek` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-elevenlabs` | 1.1.0 | 1.2.0 | minor | retained |
| `swift-ai-fal` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-fireworks` | 1.1.0 | 1.1.1 | patch | swift-ai-openai-compatible 1.1.0 → 1.2.0 |
| `swift-ai-fish-audio` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-gateway` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-gladia` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-gmicloud` | 1.1.0 | 1.1.1 | patch | swift-ai-openai-compatible 1.0.0 → 1.2.0 |
| `swift-ai-google` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-google-vertex` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0; swift-ai-google 1.1.0 → 1.2.0; swift-ai-anthropic 1.2.0 → 1.3.0; swift-ai-openai-compatible 1.1.0 → 1.2.0 |
| `swift-ai-groq` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-heygen` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-huggingface` | 1.1.0 | 1.1.0 | none | retained |
| `swift-ai-hume` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-klingai` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-lmnt` | 1.0.0 | 1.0.0 | none | retained |
| `swift-ai-luma` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-mcp` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-minimax` | 1.1.0 | 1.2.0 | minor | swift-ai-anthropic 1.2.0 → 1.3.0 |
| `swift-ai-mistral` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-moonshotai` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-open-responses` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-openai` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0; swift-ai-openai-compatible 1.1.0 → 1.2.0 |
| `swift-ai-openai-compatible` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-perplexity` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-prodia` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-quiverai` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-replicate` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-revai` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-togetherai` | 1.1.0 | 1.1.1 | patch | swift-ai-openai-compatible 1.0.0 → 1.2.0 |
| `swift-ai-topaz` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-typesafe-ai` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0 |
| `swift-ai-ui` | 1.0.0 | 1.1.0 | minor | swift-ai-core 1.0.0 → 1.3.0 |
| `swift-ai-vercel` | 1.0.0 | 1.0.0 | none | retained |
| `swift-ai-voyage` | 1.1.0 | 1.1.1 | patch | retained |
| `swift-ai-xai` | 1.1.0 | 1.2.0 | minor | swift-ai-core 1.2.0 → 1.3.0; swift-ai-openai 1.1.0 → 1.2.0; swift-ai-openai-compatible 1.1.0 → 1.2.0 |
| `swift-ai-zai` | 1.1.0 | 1.1.1 | patch | swift-ai-openai-compatible 1.0.0 → 1.2.0 |

Exact per-unit rationale and required behavior/API evidence are in `swiftReleaseDecisions` in the structured audit. Core1.3/UI1.1 are additive under the project convention, with the five enum migration caveats above; no binary ABI guarantee is claimed. Google Vertex additionally requires Anthropic1.3 and compatible1.2 for hosted shared-policy behavior, while its existing OpenAI configuration conversion remains available at the retained1.0 minimum.

## Final local verification

All52 owning packages and the complete current-source facade passed: **3,965 tests** (2,240 owning,1,725 compatibility), with33 explicit paid/live skips. The separate `sdk.mjs dev test` also passed. All27 tooling tests, generation checks,52-unit dependency closure, core/provider isolation, compatible/incompatible version controls and diff checks passed. Docs install/check/build passed with100 pages.

The catalog-wide distribution check passed52 byte-deterministic standalone exports, their owning suites and106 minimum/latest/mixed/complete consumers. These are local synthetic refs with real published lower bounds. They are separate from the real public consumers required after publication. An ordinary-import local consumer additionally passed queued receipt delivery, origin privacy, URL transcription/words, uploaded video, realtime usage and default Box instructions.

Exact-source hosted Swift6.3.3 CI, changed-unit publication, standalone hosted CI, remote ref readback and public-tag consumers remain pending at this canonical source stage. No new Swift tag or Release is claimed by local results.

Four additional exact retained-minimum consumers compile current Moonshot with Core1.2/compatible1.0, OpenResponses with Core1.2/OpenAI1.1/compatible1.1, Quiver with those dependencies plus OpenResponses1.1, and unchanged Vercel1.0 with its actual public Core1.0/compatible1.0 tags. Version-specific dependency closure was independently checked for all52 targets; catalog-wide selection alone would conservatively raise these four graphs. Exported runtime/test/resource bytes and dependency manifests match the final canonical inputs; later descriptive catalog notes are verified by final deterministic production exports.
