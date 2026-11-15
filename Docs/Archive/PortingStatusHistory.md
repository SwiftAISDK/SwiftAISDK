# Porting Status History

Archived narrative from `Docs/PortingStatus.md`: dated pass summaries and the
provider-state journal, preserved verbatim when the status page was reduced to
current state on 2026-11-15. Links inside are relative to `Docs/` as written at
the time; the dated records they mention now live in this directory. See
[Archive policy](README.md).

## 2026-11-15 upstream review

The current checkout tracks 57 npm packages across 55 Swift units. The
[package audit](WeeklyUpstreamAudit20261115.md) records 36 new npm baselines and
complete Tencent, Parallel and ScaleDown ports, plus HeyGen Decision V4.
Core signed streaming approvals and per-video MIME descriptors are additive;
all previous selectors/initializers remain. All required local checks passed:
55 owning packages, 1,736 facade tests, tooling, 55 deterministic exports and
exact minimum-dependency consumers. All 36 independent releases and SwiftAISDK 3.4.0 are published and verified.

## Modular packages

All 55 independent distributions are published: core, 52 provider adapters, MCP and UI.
The 2026-11-15 set updates 36 units: 31 patch, two additive minor and three initial
releases. Tencent, Parallel and ScaleDown are 1.0.0; core is 1.5.0 and HeyGen is
1.2.0. Nineteen unchanged units retain their published versions. Exact versions,
compatibility rationale and immutable refs are in [ReleaseVerification20261115.json](ReleaseVerification20261115.json).

All 36 exported commits passed standalone CI and 62 clean public-tag consumers.
Local verification covers 55 owning packages, 2,451 owning tests, 1,736 facade
tests, 55 deterministic exports, 112 generic consumers, eight exact historical
graphs and one complete least-version umbrella graph. Paid/live checks remain disabled.
SwiftAISDK 3.4.0 is the optional compatibility umbrella. Actual 3.4.0 and
preserved 2.8.1 consumers passed separately from the 62 modular clients. The M3
runner passed all 4,187 reported package/facade tests, iOS compilation and
examples; a controlled outage verified automatic hosted fallback. See
[M3 runner verification](M3RunnerVerification20261115.json).

## Initial 3.0 migration evidence

The migration retained existing runtime behavior, upstream baselines, capabilities
and known gaps. Local verification passed 3549 source tests (33 explicit live
skips), exported-package tests, independent-version consumers and iOS compilation.
Public 3.0.0 and 2.8.1 consumers compiled and ran. Hosted Swift 6.3.3 source tests
also passed; the redundant full migration workflow was cancelled to conserve CI.
Automatic CI now selects relevant checks, without migration rehearsals.

## Weekly upstream review (2026-11-14)

Fresh npm metadata finds 52 differing baselines among 54 tracked packages. All
52 comparisons have 104 integrity-verified archives and 1705 exact immutable
release-test files; no fallback snapshot is treated as release evidence. Separate
npm search returns 76 scoped names and the exact registry prefix returns 96.
All 43 unimplemented published packages have separately verified old/latest
archives and per-package source/entrypoint dispositions.

Two new usable providers are reported without implementation: Tencent 3.0.3
(TokenHub language/video plus TC3-signed VOD), and ScaleDown 3.0.1 (Decision and
Extraction). Inception 0.0.0 is only a seed. Previously discovered Parallel is
still unimplemented at 3.0.9. A separate ScaleDown vertical is the recommended
next small port, reusing the new native Decision/Extraction contracts.

This pass adds Extraction V4, native Google Decisions, DeepSeek Responses and
web search, MiniMax H3 images, current provider controls/metadata, reusable
compatible request/response conversion, telemetry-copy credential redaction,
protected downloads/OAuth, and native UI message queues/bounded validation.
Exact per-package decisions, tests and retained gaps are in
[WeeklyUpstreamAudit20261114.md](WeeklyUpstreamAudit20261114.md). All mandatory
local checks passed: 52 owning packages, 1731 facade tests, deterministic exports
and 106 minimum/latest clients, tooling and the 101-page documentation build.
The 48 independent releases and separate SwiftAISDK 3.3.0 umbrella are published
and verified, including exact-source hosted CI, public tag/Release readback, 59
modular consumers and two complete-umbrella consumers. No full-package or paid
live-service parity is claimed.

## Weekly upstream review (2026-11-08)

This pass compares 52 newer npm baselines across 54 tracked packages using 104
integrity-verified archives and exact matching-release tests. The 93-name registry
prefix and 76-result scoped search reveal one new model provider:
`@ai-sdk/parallel@3.0.4`. Its Decision endpoint requires a separate native provider
vertical; it is reported for the next implementation and is not added automatically.

The source review includes steering queues/UI replay, URL/timing transcription,
request-origin telemetry, admission tiers/threads/Files, refusal/tool handling,
OAuth binding/resource fixes and media lifecycle changes. Public docs and the
[package-by-package audit](WeeklyUpstreamAudit20261108.md) record the exact scope.
All local, exact-source Swift 6.3.3, independent-release, standalone-CI, public-consumer
and hosted-page gates passed. 48 changed units and separate umbrella 3.2.0 are published;
this delta review does not claim full-package parity or paid live-service acceptance.

## Weekly upstream review (2026-11-01)

The current source reviews 52 newer npm baselines using verified published archives
and exact matching-release tests. It adds lazy async credentials, nearest supported
reasoning efforts, current provider options/parsers, steering and failed-step
callbacks, descriptive model metadata and MCP input-required continuation updates.
All broader product gaps remain explicit. No new model provider was found in the
exact 92-name registry namespace. See [the complete audit](WeeklyUpstreamAudit20261101.md)
for every reference/latest version, source/test disposition and publication state.
The 48 changed Swift units passed local, export, exact-source hosted and public-tag
gates. The separate umbrella 3.1.0 and preserved 2.8.1 public consumers also
passed. The installation page was verified after successful hosted deployment.

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
