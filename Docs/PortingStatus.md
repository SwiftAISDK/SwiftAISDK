# Porting Status

Snapshot date: 2026-10-25

SwiftAISDK currently ports the provider-facing parts of Vercel AI SDK into a
SwiftPM library. The package has a broad Swift-native facade, provider registry,
provider implementations, generated provider capability docs, upstream-shaped
parity tests, and a static documentation site.

The repository is distributed under Apache-2.0; the complete terms are in the
root `LICENSE` file.

This file is the readable status page. It replaces the older provider-progress
journals and product-gap checklist. Use the ledgers and generated inventories
for exact evidence.

## Weekly upstream parity (2026-10-25)

The follow-up patch for 2.8.1 explicitly resolves the nonoptional speech
WebSocket close error so the library also compiles on the minimum Swift 6.3.3
toolchain. Local Swift 6.4 checks for 2.8.0 passed before that hosted failure was
observed; see `PostReleaseRepairAudit.md`. The 2.8.0 tag and npm baselines are
preserved.

The current pass covers ai 7.0.153, provider 4.0.34, provider-utils 5.0.68 and
all reviewed provider baselines. It adds streaming speech, incomplete-stream
semantics, final-answer JSON parsing, safer tool execution and new provider
options. See the per-package audit, current Provider State below and public
Stream speech guide. Prior dated sections preserve historical evidence.

## Post-release repairs (2026-10-23)

The repairs after the 2.6.0 audit retain its npm package baselines and provider
coverage. A fresh registry readback during this follow-up found 52 newer patch
versions; their per-package baseline/latest table and separate next-audit
disposition are in `PostReleaseRepairAudit.md`. Default untrusted downloads now use validated numeric DNS endpoints,
original-host TLS verification and bounded HTTP/1.1 framing; custom transports
opt into protected download hooks explicitly. See `DownloadSecurity.md` for
the custom-session migration and exact trusted-origin exception.

The URLSession byte adapter now reads on demand instead of filling an unbounded
queue of one-byte Data values. Offline memory measurements and scope limits are
recorded in `PostReleaseRepairAudit.md`; no whole-facade memory guarantee is
claimed. `MCPOAuthMigration` is an executable offline example for issuer-bound
secret credentials and custom token authentication. Live smoke tests now show
explicit skips, and the representative runner reports credential availability
before any paid call.

The docs dependency graph uses Astro 7.4.2, Starlight 0.42.6 and Sharp 0.35.5,
with a full clean-install npm audit reporting zero findings. CI now checks and
audits documentation as well as building it. The OpenAI fixture assertion that
failed to compile on hosted CI is split into typed intermediate values.
The multi-file OAuth example also uses a named entry-point source instead of
`main.swift` so its `@main` declaration compiles on the supported Swift 6.3
toolchain. CI executes both offline migration flows before publishing docs.

Bash tooling, UI step APIs and additional provider adapters remain separate
work, as requested. The historical release audits below describe their original
snapshots; `PostReleaseRepairAudit.md` records current repair verification.

## Current Shape

- The `AI` facade covers text, streaming text, durable text batches, structured
  output, embeddings, images, unary and asynchronous video, unary and streaming speech, batch and
  streaming transcription, reranking, Files V4 operations, skill uploads,
  middleware, telemetry, warnings, setup and in-band stream retries, aborts,
  tools, approvals, MCP tools, UI messages, chat sessions, agent helpers, and
  provider-neutral realtime sessions.
- Experimental Decision V4 is available through `AI.experimentalDecide` with
  ordered text/JSON/file evidence, typed questions/answers/refusals, optional token
  budgets/reasoning controls, Perplexity native decisions, provider/registry routing,
  and native telemetry. Existing Evaluation V4 is available through `AI.experimentalEvaluate`
  with Choice, Score, Boolean, and TypeSafe Box questions, provider/default-registry model
  resolution, a native TypeSafe AI provider, and OpenAI, Anthropic, Google, and
  Gateway adapters.
- Attached citations survive generated/streamed content, typed text output and
  native UI independently of retrieved sources; tool concurrency is configurable.
- HTTP language-model streaming consumes SSE and Amazon EventStream bodies
  incrementally through `AIStreamingTransport`; first parts can arrive before
  response EOF, and abort or early consumer termination cancels the body read.
  Send-only custom transports remain supported for unary generation and fail
  streaming explicitly instead of falling back to buffered `send`.
- Built-in language streams expose one canonical part-aware text/reasoning
  lifecycle and one terminal part per logical response. Legacy-only custom
  streams are normalized at the facade boundary, while ambiguous mixed-family
  streams fail explicitly. In-band provider errors remain observable without
  turning text-only streams into silent successes.
- Provider coverage spans the official provider-facing `@ai-sdk/*` packages
  tracked in `Docs/ProviderVersionLedger.md`.
- `Docs/ProviderCapabilityMatrix.md` is generated from
  `Sources/SwiftAISDK/Providers/ProviderCapabilityMatrix.swift` and guarded by
  tests.
- Core AI SDK parity is tracked in `Docs/CoreV6Parity.md`.
- Upstream test/spec files are inventoried in `Docs/UpstreamTestInventory.md`.
- Public docs live in `README.md` and `docs-site`.

## Baselines

| Area | Source of truth |
| --- | --- |
| Provider npm baselines | `Docs/ProviderVersionLedger.md` |
| Provider capabilities | `Sources/SwiftAISDK/Providers/ProviderCapabilityMatrix.swift`, generated into `Docs/ProviderCapabilityMatrix.md` |
| Core AI SDK parity | `Docs/CoreV6Parity.md` |
| Upstream test inventory | `Docs/UpstreamTestInventory.md` |
| Latest upstream test diff audit | `Docs/FreshUpstreamTestDiffAudit.md` |

Provider and core versions were freshly checked on 2026-10-25. All **54 tracked
packages** were reviewed: **52 version drifts and two current rows** (LMNT and
Vercel). **172 published archives** passed SHA-512 verification, including
prior/current references for mentioned framework/tooling packages. Separate
source, declaration, manifest and fixture decisions are recorded in
`Docs/UpstreamPackageDiffAudit.md`; `Docs/UpstreamPackageIntegrity.json` records
all archive identities. The fixture inventory has **1,106 executable paths in
86 groups**; the latest diff has **40 executable and three declaration paths**.

## Provider State

The 2026-10-25 pass adds native experimental streaming speech through ElevenLabs
and Gateway, with incremental text, ordered audio, provider metadata, errors,
one stream owner and cancellation. ElevenLabs also forwards dialogue, music,
sound-effect and composition-plan requests through speech factories. Mistral
Voxtral 3 supports expressiveness/IPA hints, detected language and phrase bias.

Audited language providers distinguish incomplete `interrupted` output from
explicit finishes/errors. The facade preserves partial answers and skips tool
execution and automatic continuation; native chat remembers interrupted messages
for late tool updates. None tool choice rejects calls before user callbacks or
stream consumers can act. Restored approvals use the first response per call.

OpenAI JSON output selects the last `final_answer` without dropping drafts or
metadata. Native middleware and Output parsing honor explicit empty selections.
Google continuation state resets per successful hop, and partial tool arguments
retain nested empty containers. Moonshot K3.1 adds cache mode/TTL, cache-write
usage/headers and MFJS object unions. Gateway Parallel Search exposes GA modes,
fetch controls, localization and canonical raw results. MCP strings become text
model output. Runtime identities, public docs and baselines are synchronized.

Fresh npm search returned **73 scoped names**, while exact prefix enumeration
returned **92**. All **39 untracked scoped packages** have fresh metadata,
integrity-verified artifacts and separate dispositions. The only new name,
`@ai-sdk/tool-web-fetch@1.0.3`, is a provider-independent tool. No new
unimplemented model provider was found. A separate native WebFetch pass would
need URL/domain and user-message policy, protected redirects/DNS, bounded
HTML-to-Markdown conversion, offset/cache semantics and cancellation. It was
not implemented automatically. Sandbox-backed `tool-bash@1.0.7` remains a
separate tool product; tools/specification/SpaceXAI seeds remain empty.

The additive streaming speech and provider/core APIs justify a **minor** bump
from **2.7.1**. Existing unary APIs remain available; applications should handle
`interrupted` and custom Gateway Search decoders should adopt GA snake_case
results. Existing OAuth/custom-download migration requirements still apply.
Known shared/provider gaps remain below; paid live tests were not enabled.

Final local verification: **3,543 tests / 66 suites**, **3,510 passed and 33
explicit live skips**, zero issues; **88 focused tests / 11 suites**; all **19
examples** and two offline OAuth flows; four public API examples typechecked
without diagnostics. Docs clean install/audit has zero vulnerabilities, Astro
checks four files with zero diagnostics, and the production-base build generates
**98 pages**. Final registry readback has 54 current packages and no drift.
The original Anthropic held-open-body cancellation proof remains intact.

### Earlier weekly passes

The 2026-09-27 weekly pass audited all 52 tracked core and provider/product
rows from fresh registry data and exact published tarballs. Fifty rows moved,
while LMNT and Vercel remained current. Sixteen rows required direct portable
work, Azure and provider-neutral file URIs were covered through shared/existing
behavior, five TypeScript-only cleanups required no Swift behavior change,
26 rows were version/dependency identity synchronization, and React remained
out of scope.

Core work adds generated-file materialization across generate, stream, and
batch; credential-isolating untrusted URL fetches; per-batch embedding option
transforms; L16/mu-law/A-law speech detection; evaluation callbacks and
telemetry; approval schema-input provenance; deterministic earlier-message
approval resume; UI-stream terminal callbacks; per-text-ID overlap-safe
reasoning with globally stable reasoning IDs;
reasoning-file pruning; and local-caller-only routing that rejects direct model
calls without disabling the bound caller. MCP custom environments and OAuth
client provenance now match 2.0.60. Swift continues to preserve opaque provider
file URI strings directly.

Provider work adds model-specific Alibaba structured output; Bedrock model,
forced-tool, reasoning, Mistral-ID, and Mantle routing updates; Anthropic
compaction, safeguards, Opus 5.5, effort, and toolset behavior; DeepSeek
multimodal tool results with image MIME validation; Gateway Browserbase/filter
and validated batch cancellation, plus conditional Evaluation fallback routing
with actual-response model attribution; current Google/Vertex files,
embedding, speech, metadata, and model behavior; exact Groq empty-choice
failures; Open Responses custom tools/results, transport hooks, stream
fallback, and grammar validation; current OpenAI GPT-6/schema,
positioned-reasoning, transcript, and speech behavior; xAI Responses options
and Imagine Video 1.5 reference routing; and the Perplexity 5 Agent API
migration with nullish Agent SSE fields. QuiverAI now exposes Arrow 2 language
generation over Responses in addition to its image surface.

Exact registry-prefix discovery still finds 87 live `@ai-sdk/*` names (SHA-256
`709381c5b12ec13c8b445aa504980cf42f6795f63b331ac39a3fddb4a89a47c9`).
The 51 tracked scoped names leave 36 untracked framework, harness, workflow,
sandbox, schema, telemetry, tooling, or reservation packages. No new or
unimplemented model-provider package appeared. `@ai-sdk/spacexai@0.0.0`
remains a 46-byte empty reservation with no implementation to port.

The only newly deferred portable test is resolver-backed address pinning for
generated-file downloads. URL/redirect validation and credential isolation are
implemented, but hostname validation alone does not pin the address used by
`URLSession`; that requires a deliberate platform-native resolver/transport
design.

The 2026-09-20 weekly pass audited the 50 previously tracked core and
provider/product rows: 18 were `ported`, two were `covered` by shared behavior,
and 27 were `version-only` package-local dependency or identity synchronization.
`@ai-sdk/react` remains out of scope, while LMNT and Vercel were already
current. A separately authorized same-day follow-up ports
`@ai-sdk/typesafe-ai@3.0.4` and `@ai-sdk/zai@3.0.15`, bringing the version
inventory to 52 tracked packages: 48 provider rows in the version ledger and
four core snapshots in the core parity ledger.

Exact registry-prefix discovery finds 87 live `@ai-sdk/*` names. The ledger
now tracks both provider packages discovered by that audit, leaving 36
untracked scoped packages and no known unported model-provider package. The
remaining untracked names are framework adapters, harness/workflow products,
UI bindings, telemetry, schemas, development tooling, or empty reservation
packages. In particular, provider-like `@ai-sdk/spacexai@0.0.0` is not a
model-provider release: its registry artifact contains one 46-byte file and no
description, public API, or implementation to port.

Core work adds the Evaluation V4 facade and provider adapters; dynamic local
and provider tool callers across generate, stream, and agent orchestration;
abort-aware URL prompt downloads; per-step provider/model identity and
telemetry; final-step structured generation and lossless partial structured
stream output; approval-safe history pruning and preliminary-output chat
handling; charset-aware data URLs, AAC detection, and in-flight video polling
deadlines; and coalesced MCP authorization refresh for concurrent or late stale
401 responses. Continuous realtime now supports the portable server-WebSocket
contract, with OpenAI Live joining xAI as a provider adapter.

Provider work preserves Alibaba thinking history; aligns Bedrock model-family,
strict-schema, web-tool, block-binding, and failure handling; adds Anthropic
20260318 web search/fetch behavior; gives DeepSeek its exact empty-choice
failure; and makes Google JSON Schema conversion and streamed metadata,
grounding, safety, finish, and usage accumulation lossless. TogetherAI handles
the Gemini image exception; Black Forest Labs and Fireworks enforce wall-clock
polling deadlines; ByteDance maps reference-image roles; Quiver implements its
Arrow 2 surface; and Replicate continues polling after synchronous wait expiry.
OpenAI gains current Responses, Evaluation, URL-abort, and Live behavior, while
xAI aligns its Responses and batch surfaces with 5.0.4 and retains the
documented compatibility shim for the removed upstream chat surface.

Deliberate deferred boundaries are browser WebRTC and its client-permission
startup options, provider-backed Responses delegation, non-Live OpenAI
Realtime models, Google Realtime 3.8, and JavaScript-only Node/React runtime
behavior. Z.AI and TypeSafe AI are now complete provider verticals; their
JavaScript workflow serialization helpers remain runtime-specific.

The 2026-09-13 weekly pass audits all 50 tracked core and provider/product
rows: 48 published deltas plus the current `@ai-sdk/lmnt@3.0.36` and
`@ai-sdk/vercel@3.0.30` rows. Twenty-two package deltas contain portable Swift
behavior, one is already covered by the shared runtime, 24 are package-local
version/dependency propagation, and React remains out of scope.

Core work migrates Batch V4 from a language-model-owned text-only protocol to
a provider-owned text/image service with per-request model IDs, typed results,
cancel/list operations, and compatibility shims. Anthropic, OpenAI, and
Gateway expose text batches; Google and xAI expose text and image batches with
their distinct model restrictions. Image retryability, stream tool-choice
enforcement, rerank-index validation, ToolOutputError UI parts, video webhook
failure ordering, and strict GIF/BMP signatures are also current. MCP OAuth
discovery validates initial and redirected URLs, rejects unsafe private and
link-local targets, scopes loopback trust to configured local servers, and
does not redirect credential POSTs.

Provider work preserves OpenAI recursive schema compatibility, async tools,
programmatic denial, Foundry message discriminators, explicit empty-choice
errors, image 2.5 controls, web-search include capabilities, and patch-tool
finish reasons. Gateway warning forwarding and image retryability are current;
xAI supports mixed-model text/image batches. Bedrock endpoint resolution now
matches AWS environment precedence and partition suffixes, while Vertex
performs bounded credential-free tool-result downloads. Alibaba, DeepSeek,
Groq, and Moonshot retain reasoning across empty tool-call arrays; DeepSeek and
Mistral recognize current model families. Anthropic preserves input
transformations. ByteDance, KlingAI, and MiniMax align async video callback and
status lifecycles, and Gladia exposes expanded utterances plus provider
metadata.

The generic upstream callback `runtimeContext` for embeddings/reranking remains
deferred pending a typed Swift callback/telemetry design. Swift also keeps its
existing `downloadURL`/`AIDownloadError` contract instead of adding a second
public helper solely to mirror JavaScript `getTextFromDataUrl`. Exact registry
discovery now finds 86 live `@ai-sdk/*` names; 37 are untracked. Z.AI is the
only untracked provider, while the newly added
`@ai-sdk/harness-github-copilot` package is an out-of-scope agent adapter.

The 2026-09-06 weekly pass audits all 50 tracked core and provider/product
rows: 49 published deltas and the still-current `@ai-sdk/vercel@3.0.30` row.
Seventeen deltas required portable Swift behavior, 31 were already covered by
existing generic behavior or required only identity/baseline synchronization,
and `@ai-sdk/react` remains deliberately out of scope for this SwiftPM port.
Core work adds Files V4 capability discovery, upload, metadata retrieval,
streamed download, and deletion; strict array-output bounds with
source-compatible deferred constructor validation; setup plus post-start stream
retry parity; stronger UI message replacement, approval, and metadata
restoration behavior; embedding
result-count validation; and Batch tools, tool choice, metadata, and raw finish
reason preservation.

Provider work adds Google Batch as the fifth durable batch adapter, including
strict request-key validation and thought-signature round trips; validates the
OpenAI Batch outer response envelope; preserves xAI raw finish reasons through
the batch facade; expands Bedrock structured-output, citation, sanitization,
and replay behavior; tightens Anthropic options, Azure URL normalization, and
media polling redirects; and advances MCP protocol, annotation,
structured-result, pagination, and OAuth parity. Google
Interactions now preserves response history, tool and reasoning items,
compaction state, provider references, media resolution, and system
instructions. Open Responses, OpenAI, and OpenAI-compatible adapters also gain
their current request-validation, model-filtering, transcription, image, and
response-handling deltas. Exact per-package dispositions and upstream evidence
are recorded in `Docs/UpstreamPackageDiffAudit.md` and
`Docs/FreshUpstreamTestDiffAudit.md`.

The 2026-08-31 weekly pass advances 49 of the 50 tracked provider/core rows;
`@ai-sdk/vercel@3.0.30` remains current. Portable core work adds per-call image
results, UTF-8 embedding byte budgets, Batch V4 completion webhooks and full
content/count preservation, typed provider stream errors, approval reasons and
signed persisted-call revalidation, model-visible invalid approval results,
and structured-output finish handling. Provider work covers Alibaba WAN 3,
Bedrock inference-profile/reasoning/guardrail/usage behavior, richer Anthropic
Batch, Baseten/DeepInfra/TogetherAI structured output, ByteDance last-frame
metadata, Cohere/Mistral raw usage, current DeepSeek options and metadata,
Groq reasoning/usage, Hugging Face stream errors, MCP pagination/OAuth
hardening, MiniMax video tiers, Mistral prompt cache affinity, Open Responses
reasoning summaries, OpenAI request/replay/batch fixes, generic compatible
array content and reasoning disablement, Perplexity usage, Prodia warnings,
Gateway callbacks/count validation, and xAI Responses Batch/web-search/ID
handling, including malformed known-event errors and item-local batch failures.
Google and Vertex embedding preflight limits now match the published 100-input,
250-input, and one-input Gemini multimodal contracts.

The same pass keeps scope boundaries explicit. Google Batch, Gemini 3.5 unary
and live transcription, current Google safety/usage/request changes, the shared
Vertex additions, and the broad Moonshot V1/Kimi option/media/metadata delta
are audited but deferred to dedicated provider passes. Open Responses'
experimental extension codec registry and lossless custom-event replay still
need a public Swift design. Body-read `URLError` retryability,
parsed stream-end output, and active UI parts were already covered. Typed
UI-tool schema conversion, automatic denied-chat submission/outcomes,
byte-array approval secrets, true image request splitting/per-call metadata,
and cost aggregation across split Gateway calls remain broader core/media
gaps. The Z.AI vertical that this historical pass identified was completed in
the 2026-09-20 follow-up with factory/auth, options, errors, media conversion,
registry/capability evidence, and focused tests.

The 2026-08-24 weekly pass advances 45 provider/product baselines plus `ai`,
`@ai-sdk/provider-utils`, and `@ai-sdk/react`; `@ai-sdk/provider` and
`@ai-sdk/vercel` remain current. Portable changes cover empty tool-call IDs,
Bedrock redacted reasoning and modeled stream failures, Cerebras options,
Deepgram 3.1 audio behavior, DeepSeek V4 vision/files, Gateway Batch V4,
ordered mixed batch results, webhook-aware async video, Tako Search, and
Gateway streaming transcription/token minting, Google local schema references and
Gemini 3.7+ reasoning floors, MCP unsuccessful POST/SSE handling, fragmented
Mistral tool calls, OpenAI Responses parallel wrappers, OpenAI-compatible
video/thought-signature/truncated-stream/image-usage behavior, and xAI image
moderation failures. Core changes add direct async-video start/status calls,
safer tool execution and structured streams, and stable text/reasoning part
identity. Google and Vertex Imagen factories remain available for source and
runtime compatibility despite upstream shutdown removal; removing that public
surface needs a deprecation cycle.

The 2026-08-19 focused follow-up adds Fish Audio 3.0.5 speech/transcription and
GMI Cloud 3.0.2 chat as complete provider verticals. It also ports Anthropic's
deferred programmatic-result replay; retry-covering, abort-aware structured
stream timeouts that remain active through client tool execution and typed
output streams; Batch V4 with Anthropic Messages Batch and OpenAI Responses
Batch; async Video V4 with Black Forest Labs and Fal, including native Fal
webhooks and core count splitting; Cartesia Ink 2 streaming transcription; and
provider-neutral Realtime V4 sessions with xAI as the first full adapter.
Shared download handling validates every redirect before following it and
strips provider credentials on cross-origin hops. Open Responses
provider-defined tools were rechecked and are not a Swift gap: upstream 2.0.28
intentionally warns and drops them.

The same follow-up advances 14 newly published patch baselines. Portable
changes include Fireworks JSON Schema structured output, the Gemini 3.7 Flash
`low` thinking floor, OpenAI 4.0.43 Responses `allowedTools` plus the
`computer` tool, MCP 2.0.33 protocol/OAuth hardening, and Bedrock EventStream
failure/EOF parity. OpenAI-compatible raw usage preservation already covers
its 3.0.31 delta; the remaining patch releases are dependency, version, or
forward-compatible model-ID propagation. Exact decisions are in
`Docs/UpstreamPackageDiffAudit.md`.

The 2026-08-17 weekly pass advances 43 provider baselines, the MCP product
baseline, and three changed core snapshots to current npm releases;
`@ai-sdk/provider@4.0.7` remains current. Portable changes cover array-schema
definitions and chat start status, Alibaba and Anthropic multi-turn replay,
Google schemas/errors/strict tools, Vertex Chirp 3 HD speech, scoped MCP OAuth,
Moonshot's owned chat/MFJS behavior, Open Responses and OpenAI continuation,
Gateway errors, and xAI Responses/video/speech capabilities. Exact
package-by-package decisions are recorded in
`Docs/UpstreamPackageDiffAudit.md`.

The 2026-08-10 weekly pass advances all 44 provider/product package baselines
and all four core snapshots to current npm releases. Portable deltas cover
streamed tool-call identity/finalization, default instructions, agent and chat
cancellation settings, Baseten HTTP embeddings and usage, Bedrock empty-message
filtering, Anthropic advisor/stream/replay behavior, MiniMax H3 aspect ratios,
OpenAI-compatible usage, OpenAI Responses correlation/serialization, and FLUX
3 video through the existing unary model contract. Exact per-package decisions
are recorded in `Docs/UpstreamPackageDiffAudit.md`.

The 2026-08-12 transport correction replaces buffered replay in every
streaming-capable built-in language provider with incremental SSE or Amazon
EventStream parsing. It also unifies MCP SSE parsing, validates Bedrock frame
lengths and CRCs, preserves typed non-success HTTP errors before the first
part, and wires consumer termination and aborts through to URLSession. Prodia
and the protocol-default stream remain explicitly unary/simulated.

The 2026-08-13 semantic-stream correction removes paired legacy and part-aware
deltas from built-in providers, normalizes legacy-only custom model streams at
the high-level boundary, closes content lifecycles deterministically, and
defines one built-in terminal outcome per logical response. Cross-surface regressions
cover text and reasoning collection, structured output, UI reduction, tool
loops, in-band errors, thrown failures, and provider terminal behavior.

Exact registry-prefix discovery on 2026-09-13 found 86 live `@ai-sdk/*`
packages and identified `@ai-sdk/zai@3.0.10` as the sole provider gap at that
time. Z.AI was subsequently ported at 3.0.15 on 2026-09-20. The other untracked
scoped packages were framework adapters, harness/sandbox/workflow products, UI
bindings, telemetry, or development tooling rather than provider model
packages; they need separate product decisions and shared runtime foundations
instead of automatic provider ports.

Do not reopen a provider just because it might have drifted. Reopen it only when
one of these is true:

- npm publishes a newer tracked package version and the port intentionally syncs
  it;
- upstream adds a provider-facing package that SwiftAISDK decides to track;
- a focused test, live smoke test, or user bug report identifies a concrete
  behavior mismatch;
- the shared Swift core contract changes in a way that affects the provider;
- an out-of-scope difference becomes an in-scope product decision.

## Active Product Gaps

| Priority | Gap | Next action |
| --- | --- | --- |
| P1 | Google/Vertex Gemini transcription and Open Responses extension codecs remain absent native adapters. | Design and port each complete request/stream/replay surface before advertising parity. |
| P0 | Completion evidence can drift as npm packages and upstream tests change. | Before release, rerun package discovery, regenerate upstream inventory, compare ledgers, run full `swift test`, and record the audit. |
| P0 | Live verification is representative, not exhaustive. | Add opt-in live smoke only for distinct transport families or concrete production risks. Keep it disabled by default. |
| P2 | Native Anthropic Messages ends and cancels its body at the first message_stop; the JS codec can consume multiple messages in one body. | Keep the existing single-response cancellation contract. A future multi-message session needs an explicit lifecycle/EOF mode and independent cleanup tests. |
| P2 | The URLSession byte adapter is now demand-driven, but still produces one Data value per byte; Foundation and higher-level parser/tool-loop buffers do not have a whole-facade memory bound. | Use the offline memory probe before a separate chunked-delegate or low-memory API design; retain injected-session compatibility and cancellation behavior. |
| P1 | xAI realtime and OpenAI Live server WebSocket are represented, but browser WebRTC/client permissions, provider-backed Responses delegation, non-Live OpenAI Realtime, Google Realtime 3.8, ElevenLabs realtime STT, and streaming translation remain deferred. | Extend `AIRealtimeModelV4` one complete transport/provider vertical at a time; do not advertise browser or delegation modes until their native lifecycle is implemented and tested. |
| P1 | Batch V4 has Anthropic, OpenAI Responses, Gateway, Google, and xAI adapters. Async Video V4 has Black Forest Labs, Fal, ByteDance, Gateway, Topaz and HeyGen adapters, but other capable providers still use unary or internal-polling paths. | Migrate additional batch/video providers incrementally when persisted operation state, native webhook behavior, and provider-specific cancellation semantics can be translated with focused tests. |
| P1 | Browser HTTP/WebSocket chat framing, Node stream-response helpers, tracing-channel/workflow codecs and legacy EventSource SSE are not native adapters. | Add a complete native public adapter only after lifecycle, replay, auth and serialization behavior are designed and tested. |
| P1 | Upstream preserves repeated tool-call IDs across explicit UI stream steps; Swift stream parts do not expose step boundaries. | Add a public step-boundary representation, then scope reducer tool-part identity to the active step with backwards lookup for late results. |
| P1 | The nonoptional Swift stopSequences array cannot distinguish omitted from explicitly empty input for Bedrock warning parity. | Introduce an additive presence-aware request representation before changing this warning behavior. |
| P1 | Provider option ergonomics are harder to discover than the core facade. | Add compact provider option examples to docs-site for non-obvious schemas and Swift differences. |
| P1 | Tooling is broad but can be more polished. | Improve validation diagnostics, typed result/error surfaces, and provider-defined tool helper docs. |
| P1 | Structured output works, but schema ecosystem parity is intentionally Swift-native. `Output.array` construction remains nonthrowing for source compatibility; invalid bounds are rejected at execution before model work begins. | Keep improving schema adapter ergonomics, repair telemetry, provider-specific structured-output examples, and docs. |
| P1 | UI/agent scope should stay explicit. | Document whether each upstream UI/agent helper is ported, Swift-native, or out of scope before adding adjacent APIs. |

## Live Verification

Default tests use mock transports. Optional live smoke tests are disabled by
default because they require real credentials and can spend money:

```sh
LIVE_AI_TESTS=1 swift test --filter LiveProviderSmoke
```

The live suite reads provider-specific environment variables such as
`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `DEEPSEEK_API_KEY`,
`ASSEMBLYAI_API_KEY`, `ELEVENLABS_API_KEY`, `CARTESIA_API_KEY`, and
`OPENAI_COMPATIBLE_API_KEY`. See `Docs/ProviderCapabilityMatrix.md` for the
current live-smoke notes and model override variables.

Deterministic loopback transport tests gate response EOF and verify that a
semantic delta arrives first, so incremental delivery and network cancellation
do not depend on paid live credentials.

## Release Readiness Checklist

Before calling a porting round release-ready:

- `Scripts/check-upstream-versions.js --discover-packages --discover-kind provider,adapter,core` has been reviewed.
- Changed tracked packages have old-vs-new upstream diffs inspected.
- `Scripts/update-upstream-test-inventory.js` has refreshed
  `Docs/UpstreamTestInventory.md` when upstream tests are part of the pass.
- `Docs/ProviderVersionLedger.md` matches the package versions actually used.
- `Docs/ProviderCapabilityMatrix.md` matches `AIProviderCapabilities`.
- Public docs in README/docs-site match the behavior users now see.
- Focused Swift tests and full `swift test` pass, or skipped verification is
  explicitly recorded.
