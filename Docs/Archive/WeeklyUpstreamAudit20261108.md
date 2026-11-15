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

Final local suites, tooling, deterministic exports/minimum ranges, exact-source Swift 6.3.3 CI, changed-only publication, immutable ref readback, all 48 standalone CI jobs and clean public-tag consumers passed. Complete evidence is in ReleaseVerification20261108.json. ByteDance, Hugging Face, LMNT and Vercel require no runtime release for a reviewed baseline alone. Shared-core verification does not automatically release unchanged providers.

## Published independent Swift release selection

48 changed units:21 minor and27 patch releases. Four unchanged runtime distributions keep their published versions. Direct minima below change only for concrete new API or required inherited behavior; shared-helper verification still covers all52 packages. All publication and validation gates below passed.

| Swift package | Previous | Released | SemVer | Direct minimum changes |
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

## Verified publication refs

Canonical runtime source: `8e233ff96fb809445aff9a5c06bb6149a24b94da`; [exact Swift 6.3.3/iOS/examples CI](https://github.com/SwiftAISDK/SwiftAISDK/actions/runs/42445272856). All 48 changed units passed their standalone hosted CI, remote main/annotated/peeled-tag/Release target and export-hash checks. The four unchanged releases retain their versions.

Separate umbrella: [SwiftAISDK 3.2.0](https://github.com/SwiftAISDK/SwiftAISDK/releases/tag/3.2.0), target `e5b635c2e0da75da4b86c78c92770b9ca48f59f9`, annotated object `22de6e93e70751ab60b71506e8ab1a98d20d6479`. Both 3.2.0 and preserved2.8.1 clean complete consumers passed, in addition to 59 modular consumers. The actual [installation page](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/) matched the completed hosted deployment.

| Changed package | Released tag | Export commit | GitHub Release |
|---|---|---|---|
| `swift-ai-alibaba` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-alibaba/tree/1.1.1) | [95bd81f841aa](https://github.com/SwiftAISDK/swift-ai-alibaba/commit/95bd81f841aa614a47b2ec6abbde9723dcd5f2f5) | [verified](https://github.com/SwiftAISDK/swift-ai-alibaba/releases/tag/1.1.1) |
| `swift-ai-amazon-bedrock` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-amazon-bedrock/tree/1.1.1) | [aacd6fcaf42a](https://github.com/SwiftAISDK/swift-ai-amazon-bedrock/commit/aacd6fcaf42a9fa0c190c937c42a841451932bab) | [verified](https://github.com/SwiftAISDK/swift-ai-amazon-bedrock/releases/tag/1.1.1) |
| `swift-ai-anthropic` | [1.3.0](https://github.com/SwiftAISDK/swift-ai-anthropic/tree/1.3.0) | [305712584825](https://github.com/SwiftAISDK/swift-ai-anthropic/commit/3057125848253dd117262a967502f55e7e0b0942) | [verified](https://github.com/SwiftAISDK/swift-ai-anthropic/releases/tag/1.3.0) |
| `swift-ai-anthropic-aws` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-anthropic-aws/tree/1.2.0) | [b15f33a8cea7](https://github.com/SwiftAISDK/swift-ai-anthropic-aws/commit/b15f33a8cea759276b2445fc8a8494d8afea3bf7) | [verified](https://github.com/SwiftAISDK/swift-ai-anthropic-aws/releases/tag/1.2.0) |
| `swift-ai-assemblyai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-assemblyai/tree/1.1.1) | [26b5ba117544](https://github.com/SwiftAISDK/swift-ai-assemblyai/commit/26b5ba11754476bdb87112db01314ad265539f2a) | [verified](https://github.com/SwiftAISDK/swift-ai-assemblyai/releases/tag/1.1.1) |
| `swift-ai-azure` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-azure/tree/1.2.0) | [abe24ae83dd4](https://github.com/SwiftAISDK/swift-ai-azure/commit/abe24ae83dd4f9526c14a040a31fe8beee0e90e9) | [verified](https://github.com/SwiftAISDK/swift-ai-azure/releases/tag/1.2.0) |
| `swift-ai-baseten` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-baseten/tree/1.1.1) | [5047d7b0033e](https://github.com/SwiftAISDK/swift-ai-baseten/commit/5047d7b0033e03a55a550ae167deb2a30fd3bfe9) | [verified](https://github.com/SwiftAISDK/swift-ai-baseten/releases/tag/1.1.1) |
| `swift-ai-black-forest-labs` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-black-forest-labs/tree/1.1.1) | [58a3c911205c](https://github.com/SwiftAISDK/swift-ai-black-forest-labs/commit/58a3c911205c945dfbdf3015eaf16425a9ff398c) | [verified](https://github.com/SwiftAISDK/swift-ai-black-forest-labs/releases/tag/1.1.1) |
| `swift-ai-cartesia` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-cartesia/tree/1.2.0) | [ef7116074e6e](https://github.com/SwiftAISDK/swift-ai-cartesia/commit/ef7116074e6e76061f42dec0c8afa2f06ff138b7) | [verified](https://github.com/SwiftAISDK/swift-ai-cartesia/releases/tag/1.2.0) |
| `swift-ai-cerebras` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-cerebras/tree/1.2.0) | [92ebe9fea55d](https://github.com/SwiftAISDK/swift-ai-cerebras/commit/92ebe9fea55d80aae36f9f91d00cdb807ff09de0) | [verified](https://github.com/SwiftAISDK/swift-ai-cerebras/releases/tag/1.2.0) |
| `swift-ai-cohere` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-cohere/tree/1.2.0) | [b68d25210e9e](https://github.com/SwiftAISDK/swift-ai-cohere/commit/b68d25210e9e89fb9ddd35a1cbf885b6bb11ca92) | [verified](https://github.com/SwiftAISDK/swift-ai-cohere/releases/tag/1.2.0) |
| `swift-ai-core` | [1.3.0](https://github.com/SwiftAISDK/swift-ai-core/tree/1.3.0) | [08eb81c15a45](https://github.com/SwiftAISDK/swift-ai-core/commit/08eb81c15a457d7a7cac08df56e2562e0fb0e290) | [verified](https://github.com/SwiftAISDK/swift-ai-core/releases/tag/1.3.0) |
| `swift-ai-deepgram` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-deepgram/tree/1.2.0) | [7be90ca732dc](https://github.com/SwiftAISDK/swift-ai-deepgram/commit/7be90ca732dc0245c23c17d8d6a10283fc18b4fd) | [verified](https://github.com/SwiftAISDK/swift-ai-deepgram/releases/tag/1.2.0) |
| `swift-ai-deepinfra` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-deepinfra/tree/1.1.1) | [9c76c6927869](https://github.com/SwiftAISDK/swift-ai-deepinfra/commit/9c76c6927869c60ed3f5d99916368831528af885) | [verified](https://github.com/SwiftAISDK/swift-ai-deepinfra/releases/tag/1.1.1) |
| `swift-ai-deepseek` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-deepseek/tree/1.1.1) | [580ddf18865b](https://github.com/SwiftAISDK/swift-ai-deepseek/commit/580ddf18865bcfe03035d64e665a1339914485d7) | [verified](https://github.com/SwiftAISDK/swift-ai-deepseek/releases/tag/1.1.1) |
| `swift-ai-elevenlabs` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-elevenlabs/tree/1.2.0) | [d9d387999502](https://github.com/SwiftAISDK/swift-ai-elevenlabs/commit/d9d38799950258c029e05f4f646abdc40e694b0d) | [verified](https://github.com/SwiftAISDK/swift-ai-elevenlabs/releases/tag/1.2.0) |
| `swift-ai-fal` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-fal/tree/1.1.1) | [8e4f3ad8a2f0](https://github.com/SwiftAISDK/swift-ai-fal/commit/8e4f3ad8a2f0cd71e4fa22af0f92b7c32135de84) | [verified](https://github.com/SwiftAISDK/swift-ai-fal/releases/tag/1.1.1) |
| `swift-ai-fireworks` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-fireworks/tree/1.1.1) | [158ab0806757](https://github.com/SwiftAISDK/swift-ai-fireworks/commit/158ab080675722cbf23b9dd9e597d359dc215574) | [verified](https://github.com/SwiftAISDK/swift-ai-fireworks/releases/tag/1.1.1) |
| `swift-ai-fish-audio` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-fish-audio/tree/1.1.1) | [cc15b1787663](https://github.com/SwiftAISDK/swift-ai-fish-audio/commit/cc15b178766347e8d019c11b2703c85d3bd1bb5f) | [verified](https://github.com/SwiftAISDK/swift-ai-fish-audio/releases/tag/1.1.1) |
| `swift-ai-gateway` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-gateway/tree/1.2.0) | [070597f7f95b](https://github.com/SwiftAISDK/swift-ai-gateway/commit/070597f7f95b77b403677f772995a973831ba757) | [verified](https://github.com/SwiftAISDK/swift-ai-gateway/releases/tag/1.2.0) |
| `swift-ai-gladia` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-gladia/tree/1.2.0) | [144f2c20f24a](https://github.com/SwiftAISDK/swift-ai-gladia/commit/144f2c20f24a8ac9ace5c215f940d34665ccbd7f) | [verified](https://github.com/SwiftAISDK/swift-ai-gladia/releases/tag/1.2.0) |
| `swift-ai-gmicloud` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-gmicloud/tree/1.1.1) | [0a9db14ebfd7](https://github.com/SwiftAISDK/swift-ai-gmicloud/commit/0a9db14ebfd77e28458aeaf8fddc5fdef1616306) | [verified](https://github.com/SwiftAISDK/swift-ai-gmicloud/releases/tag/1.1.1) |
| `swift-ai-google` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-google/tree/1.2.0) | [a624886292a4](https://github.com/SwiftAISDK/swift-ai-google/commit/a624886292a421ab66dad9abc4cf3a01bcb5151c) | [verified](https://github.com/SwiftAISDK/swift-ai-google/releases/tag/1.2.0) |
| `swift-ai-google-vertex` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-google-vertex/tree/1.2.0) | [051494928862](https://github.com/SwiftAISDK/swift-ai-google-vertex/commit/05149492886282f575a5d6c86c127e25896f28e9) | [verified](https://github.com/SwiftAISDK/swift-ai-google-vertex/releases/tag/1.2.0) |
| `swift-ai-groq` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-groq/tree/1.2.0) | [8faf3ddfb8d6](https://github.com/SwiftAISDK/swift-ai-groq/commit/8faf3ddfb8d61c02d3899de14e93a6a7fb4ccc74) | [verified](https://github.com/SwiftAISDK/swift-ai-groq/releases/tag/1.2.0) |
| `swift-ai-heygen` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-heygen/tree/1.1.1) | [f3e54cb4276b](https://github.com/SwiftAISDK/swift-ai-heygen/commit/f3e54cb4276b1470c0e8e6ffd276c2bd24f267b5) | [verified](https://github.com/SwiftAISDK/swift-ai-heygen/releases/tag/1.1.1) |
| `swift-ai-hume` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-hume/tree/1.1.1) | [301f0cb906c8](https://github.com/SwiftAISDK/swift-ai-hume/commit/301f0cb906c80f1d3f581cde5719f64f6b17702e) | [verified](https://github.com/SwiftAISDK/swift-ai-hume/releases/tag/1.1.1) |
| `swift-ai-klingai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-klingai/tree/1.1.1) | [8c8a171b86fc](https://github.com/SwiftAISDK/swift-ai-klingai/commit/8c8a171b86fc81211fbd9e302341b4d904a124ed) | [verified](https://github.com/SwiftAISDK/swift-ai-klingai/releases/tag/1.1.1) |
| `swift-ai-luma` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-luma/tree/1.1.1) | [d7011d060a19](https://github.com/SwiftAISDK/swift-ai-luma/commit/d7011d060a1940089a1c433d21d8cc0c0c351dbf) | [verified](https://github.com/SwiftAISDK/swift-ai-luma/releases/tag/1.1.1) |
| `swift-ai-mcp` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-mcp/tree/1.1.1) | [6fa438545f95](https://github.com/SwiftAISDK/swift-ai-mcp/commit/6fa438545f9535e463841e95166c1825923c8598) | [verified](https://github.com/SwiftAISDK/swift-ai-mcp/releases/tag/1.1.1) |
| `swift-ai-minimax` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-minimax/tree/1.2.0) | [5ffe788d8625](https://github.com/SwiftAISDK/swift-ai-minimax/commit/5ffe788d86258881f2dacf0049d7ddb614e66f23) | [verified](https://github.com/SwiftAISDK/swift-ai-minimax/releases/tag/1.2.0) |
| `swift-ai-mistral` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-mistral/tree/1.2.0) | [4cb0cd3c3115](https://github.com/SwiftAISDK/swift-ai-mistral/commit/4cb0cd3c3115db068fd4409f1256c566165956d4) | [verified](https://github.com/SwiftAISDK/swift-ai-mistral/releases/tag/1.2.0) |
| `swift-ai-moonshotai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-moonshotai/tree/1.1.1) | [7f5588f8203e](https://github.com/SwiftAISDK/swift-ai-moonshotai/commit/7f5588f8203e71b01c89db70db200bbe7efde854) | [verified](https://github.com/SwiftAISDK/swift-ai-moonshotai/releases/tag/1.1.1) |
| `swift-ai-open-responses` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-open-responses/tree/1.1.1) | [fdf30c519789](https://github.com/SwiftAISDK/swift-ai-open-responses/commit/fdf30c519789cf6c589c706916a75d5f39cdf0e5) | [verified](https://github.com/SwiftAISDK/swift-ai-open-responses/releases/tag/1.1.1) |
| `swift-ai-openai` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-openai/tree/1.2.0) | [ad463db6b289](https://github.com/SwiftAISDK/swift-ai-openai/commit/ad463db6b2895b28f9d73ebcffbca280cdb8bd61) | [verified](https://github.com/SwiftAISDK/swift-ai-openai/releases/tag/1.2.0) |
| `swift-ai-openai-compatible` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-openai-compatible/tree/1.2.0) | [20e8e91abae0](https://github.com/SwiftAISDK/swift-ai-openai-compatible/commit/20e8e91abae0eb9a3e7ff823fc84ed907d16f65c) | [verified](https://github.com/SwiftAISDK/swift-ai-openai-compatible/releases/tag/1.2.0) |
| `swift-ai-perplexity` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-perplexity/tree/1.1.1) | [e6aff3721676](https://github.com/SwiftAISDK/swift-ai-perplexity/commit/e6aff3721676d619a29ff6b015295ef60689e027) | [verified](https://github.com/SwiftAISDK/swift-ai-perplexity/releases/tag/1.1.1) |
| `swift-ai-prodia` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-prodia/tree/1.1.1) | [cac1bd6ae227](https://github.com/SwiftAISDK/swift-ai-prodia/commit/cac1bd6ae2279f7d6297d8a4090f884c7f7e17e9) | [verified](https://github.com/SwiftAISDK/swift-ai-prodia/releases/tag/1.1.1) |
| `swift-ai-quiverai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-quiverai/tree/1.1.1) | [1071f75bb48d](https://github.com/SwiftAISDK/swift-ai-quiverai/commit/1071f75bb48d10acdfadbeb043f2436cf3f6159e) | [verified](https://github.com/SwiftAISDK/swift-ai-quiverai/releases/tag/1.1.1) |
| `swift-ai-replicate` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-replicate/tree/1.1.1) | [63b44d7e8110](https://github.com/SwiftAISDK/swift-ai-replicate/commit/63b44d7e811040601ac58f149b0995fb3354a165) | [verified](https://github.com/SwiftAISDK/swift-ai-replicate/releases/tag/1.1.1) |
| `swift-ai-revai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-revai/tree/1.1.1) | [60953796909a](https://github.com/SwiftAISDK/swift-ai-revai/commit/60953796909a3fa1ffd4259b783126b67d80f582) | [verified](https://github.com/SwiftAISDK/swift-ai-revai/releases/tag/1.1.1) |
| `swift-ai-togetherai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-togetherai/tree/1.1.1) | [f3b2a21fbe88](https://github.com/SwiftAISDK/swift-ai-togetherai/commit/f3b2a21fbe88cb3a53da9d3cdbc2c43f7a42da26) | [verified](https://github.com/SwiftAISDK/swift-ai-togetherai/releases/tag/1.1.1) |
| `swift-ai-topaz` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-topaz/tree/1.1.1) | [fb4d8b00e734](https://github.com/SwiftAISDK/swift-ai-topaz/commit/fb4d8b00e734b558281ae95b5a63ddc094fde389) | [verified](https://github.com/SwiftAISDK/swift-ai-topaz/releases/tag/1.1.1) |
| `swift-ai-typesafe-ai` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-typesafe-ai/tree/1.2.0) | [07a28b2c6941](https://github.com/SwiftAISDK/swift-ai-typesafe-ai/commit/07a28b2c6941644595480aeacae305a7b442dbb0) | [verified](https://github.com/SwiftAISDK/swift-ai-typesafe-ai/releases/tag/1.2.0) |
| `swift-ai-ui` | [1.1.0](https://github.com/SwiftAISDK/swift-ai-ui/tree/1.1.0) | [88daef054927](https://github.com/SwiftAISDK/swift-ai-ui/commit/88daef05492772b3859c29b1beb8383ad1650fa0) | [verified](https://github.com/SwiftAISDK/swift-ai-ui/releases/tag/1.1.0) |
| `swift-ai-voyage` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-voyage/tree/1.1.1) | [ff11771e2f90](https://github.com/SwiftAISDK/swift-ai-voyage/commit/ff11771e2f90ef45fcc6835984f17e86438120a9) | [verified](https://github.com/SwiftAISDK/swift-ai-voyage/releases/tag/1.1.1) |
| `swift-ai-xai` | [1.2.0](https://github.com/SwiftAISDK/swift-ai-xai/tree/1.2.0) | [91b9a8b31814](https://github.com/SwiftAISDK/swift-ai-xai/commit/91b9a8b31814d5a93a63d3a25136342c976fe8a8) | [verified](https://github.com/SwiftAISDK/swift-ai-xai/releases/tag/1.2.0) |
| `swift-ai-zai` | [1.1.1](https://github.com/SwiftAISDK/swift-ai-zai/tree/1.1.1) | [3b4695f23450](https://github.com/SwiftAISDK/swift-ai-zai/commit/3b4695f234505f355b6f14a026f527871208688f) | [verified](https://github.com/SwiftAISDK/swift-ai-zai/releases/tag/1.1.1) |

Full annotated tag objects, peeled commits, Release targets, export SHA-256 values, exact CI jobs and clean lockfiles are in the structured audit and release verification. No published tag was moved. Browser media/LiveKit, Gateway incremental image decoding, separate Google transcription/speech translation and the proposed Parallel provider remain explicit gaps; no full-package or paid live-service parity is claimed.
