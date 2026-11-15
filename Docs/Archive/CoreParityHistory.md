# Core Parity History

Archived dated core deltas and package diff notes from `Docs/CoreV6Parity.md`,
preserved verbatim when that page was reduced to the current parity reference on
2026-11-15. Links are relative to `Docs/` as written at the time. See
[Archive policy](README.md).


Post-release native repair: the default download transport now pins validated
DNS addresses and retains original-host TLS trust. Custom download hooks fail
closed unless implemented explicitly. URLSession response-byte adaptation is
demand-driven; its queue is bounded without claiming JS low-memory result
semantics or a whole-facade retention bound. The offline OAuth migration example
exercises the existing published MCP 2.0.81 binding contract. See
`Archive/PostReleaseRepairAudit.md` and `DownloadSecurity.md` for current evidence and
compatibility details; older dated audit sections retain their historical state.

## 2026-11-15 Native delta

Signed historical approvals now execute the validated approved input without a
second refinement. Three explicit `toolApprovalSecret:` streaming overloads
verify signatures while preserving every earlier selector and unsigned behavior.
The original matching-release counter fixture exposed execution of 3 after
approval of 2; unary and streaming tests now check accepted/rejected replay,
execution counts, tampered signatures and unchanged history.

`VideoURLDescriptor` and `VideoGenerationResult.videoURLDescriptors` preserve
per-file MIME associations, including async video fan-out. Existing result
initializers and common media-type fields remain available. Tencent uses these
for TokenHub and VOD outputs. The typed native bounded-UI validation scenarios
retain the upstream limits/first-index assertions; JS getters, reference mutation
and invalid TS union shapes are recorded as platform-only distinctions.

The [weekly audit](Archive/WeeklyUpstreamAudit20261115.md) includes every reviewed package,
full new-provider test dispositions and the separate local/hosted/release gates.

## 2026-11-08 Native delta

The reviewed delta adds per-task steering queues and delivered-message stream/UI
history, keepalive pings, low-level endpoint metadata with high-level origin
sanitization, telemetry content-capture filtering, native URL transcription and
word timings, caller-storage uploaded-video descriptors, and video/reranking/
decision capability sections. Tool approval metadata is rebuilt from current
trusted definitions. Shared provider-option resolution and tool-alias precedence
are explicit. Realtime usage and intent overloads preserve existing event case
arity; exhaustive language-stream/UI switches must handle the new cases.

Default downloads also reject HTTPS-to-HTTP redirects. Swift Data/JSONValue
semantics already avoid JS cross-realm, BigInt and reference-cycle behavior; the
new JavaScript binary-field scanner memory optimization and durable workflow/
Node tracing hooks have no matching native product surface. Native buffering and
browser transport limitations remain explicit. See
[the package audit](Archive/WeeklyUpstreamAudit20261108.md) for matching-release evidence,
fixture dispositions and the completed verification/publication state.

## 2026-11-01 Native delta

Experimental steering provides per-run queues, idempotent delivery receipts and
step-boundary metadata across unary, streaming, typed output and agent APIs.
Failed-step callbacks and telemetry preserve step indices and original errors;
normal completion and cancellation settle receipts independently. Events and
execution contexts carry the reviewed aiVersion. Native maxSteps defaults are
preserved and documented rather than replaced by JavaScript defaults.

SwiftAIProvider adds descriptive model/option support metadata and Codable native
catalog entries. Shared transport resolves rotating credentials per authenticated
send/stream/connect, and reasoning maps to the closest supported level while
preserving explicit provider overrides. Foundation Data already supplies base64
encoding; Node Buffer fast paths and new sandbox types are separate JS mechanics
or products. The React browser-renderer export alias changes no native SwiftUI API.
See [the per-package audit](Archive/WeeklyUpstreamAudit20261101.md) for exact release-test
provenance, translated tests, native adaptations and retained gaps.

## 2026-10-25 Native Parity

`AI.experimentalStreamSpeech` accepts complete or incremental text through native
speech models and returns one owned audio/full stream with async result metadata.
ElevenLabs and Gateway implement the additive StreamingSpeechModel contract.
Cancellation stops input/provider work; no-audio and premature EOF are explicit
failures. Provider usage remains JSON and audio is not retained for replay.
Native speech frame parsing/serialization mirrors the published envelope.

`TextGenerationResult.structuredOutputText` is optional, defaults to nil and
selects JSON parsing text independently of complete generated content. OpenAI
Responses selects the last final_answer; an explicit empty selection is not a
fallback. Object/Output facades and JSON/reasoning extraction preserve this
selection, drafts, citations and metadata.

`toolChoice: none` rejects calls before repair/refinement/execution callbacks and
withholds tool parts from streaming consumers. Interrupted output bypasses
required/forced missing-tool checks, execution and automatic continuation.
Restored repeated/conflicting approvals collect only the first response per call.
Native chat retains interruption state after response cleanup. MCP strings map
to text model output while null/other primitives remain safe JSON.

The earlier monorepo interruption, approval and Gateway Search GA follow-ups are
now published and covered. Browser UI wire/steps, JS low-memory result/getter
semantics, framework/workflow/OTel adapters and sandbox tools remain separate
products or documented gaps; no equivalent whole-facade memory claim is made.

## 2026-10-23 Native Parity

Decision calls, provider call options, callbacks and telemetry accept optional
`maxOutputTokens` and `reasoning`; invalid budgets fail before I/O. Language
adapters forward the controls and default reasoning to none. Choice/Score/Boolean
instructions default to native `.null`, Score supports one level, and Boolean
without instructions requires a described criterion. Box and legacy Evaluation
validation retain their stricter requirements. Perplexity now exposes its native
Decision adapter with image evidence, full-precision answers, confidence/legends
and exact answer-key validation. Provider-specific restrictions still apply.

Pruning removes consecutive reasoning/reasoning-file groups when all following
content up to the next group is pruned. Native UI tool IDs retain the latest
nonempty tool name. A shared path-segment helper protects reserved characters
and standalone dot IDs in media status and file/skill routes; downloads reject
`.internal` hosts. Native owned Data accumulation covers the JS backing-buffer
retention fix without retaining views.

MCP HTTP discovery waits within the caller's initialization budget; stdio keeps
its short capability probe. Stdio shell execution is explicitly selectable and
defaults off. OAuth flow pins cannot override credential issuer/endpoint bindings,
unbound secrets are rejected, and invalid-grant recovery retains validated token
binding. Native custom token authenticators declare `usesCustomClientAuthentication`
and must supply an issuer or stored binding; Swift cannot detect an overridden
optional protocol hook implicitly.

The renamed JS `experimental_streamTextLowMemory` result/replay/getter API
remains deferred; native AsyncSequence APIs make no equivalent memory bound
promise. TypeScript optional tool-set inference and React dependency-only changes
need no Swift runtime counterpart. Monorepo interrupted-stream/approval follow-up
fixtures and Gateway parallel-search GA changes remain ahead of this published
snapshot. UI wire/step, realtime and provider-specific gaps remain in
PortingStatus. DNS pinning was still a gap in 2.6.0 and is closed by the
post-release repair described above.

## 2026-10-18 Native Parity

Citations are attached to individual generated text blocks and streaming text
endings, independently of retrieved sources. `AICitation` preserves source,
optional UTF-16 output offsets and quoted text. Existing uncited enum cases and
constructors remain valid; cited blocks use `.citedText`, cited endings use
`.textEndWithCitations`, and raw custom-tool input starts use `.toolInputStartText`.
Exhaustive switches over these public enums must handle the new cases. Facade
aggregation, simulated streaming, typed text output, middleware and native UI
retain the citation blocks and provider metadata.

`LanguageModelRequest.toolCallConcurrency` bounds local tool execution; nil is
unlimited and 1 is sequential. It applies to generate, stream, restored approvals
and agent/chat requests. Sequential executions and all returned results retain model-call order;
failure/abort prevents queued work from starting. Missing local tool
results are validated even when an approval response is present. Raw text tool
input deltas retain their encoding and become a JSON string at final execution.

Decision V4 adds normalized finite ordered `AIDecisionBox` edges and `.box`
questions/answers. TypeSafe AI accepts PNG/JPEG evidence, explicit/automatic
image references, multipart requests and typed experimental `longContext`
options. Other decision adapters reject Box before I/O. Choice maximum checks
allow the declared rounding error on both compared probabilities; language
adapters accept either internal choice codes or an exact choice label. Supported
URL matching preserves case-sensitive paths and query strings.

Managed MCP subscriptions support nullable `ttlMs`: nil keeps an application
subscription until explicitly stopped. The old `expiresAt` constructor is retained
with a deprecation for source compatibility. MCP tools already permit execution
without explicit native execution options. The existing native multi round-trip
form implementation remains covered separately from the published npm client.

The JavaScript `experimental_lowMemory` result/replay/getter-retention facade is
not exposed by this provider-facing port. Native AsyncSequence consumption has
a different result API; this release makes no equivalent memory-bound claim.
Browser visibility/resume, React hook stale-closure and HTTP reconnect races,
Node process-global configuration, TypeScript inference and workflow serializers
remain runtime-specific. Existing UI wire/step and other shared gaps below remain
open. Published behavior controls parity; monorepo-only Perplexity decisions and
MCP stdio shell changes are not adopted.

## 2026-10-11 Native Parity

Decision V4 adds `AI.experimentalDecide`, ordered text/JSON/file state, normalized media, strict answers/refusals, provider/registry routing and `ai.decide` telemetry. Legacy Evaluation calls retain their public signatures and JSON-array semantics; new ordered legacy state uses `stateParts:`. OpenAI now calls `/decisions`, Gateway `/decision-model`, and language-adapter schemas are named `decision`. Custom endpoint emulators must follow these experimental envelopes.

Shared embedding dimensions validate before I/O, including empty batches, and provider overrides win. Raw usage is retained when summing one nonempty operand. Empty tool messages merge provider metadata. `AISerialJobExecutor.waitForIdle` covers nested and failed work. `AIReasoningDelimiters` supports literal opening/closing strings without treating them as regex. Default `AIAgent` stop conditions cap continuing loops at 20 steps and warn only when that default ends the loop; custom conditions and natural endings remain quiet.

Stream terminal model parts stop first/chunk timers before postprocessing; total/step budgets continue to include application work. Explicit abort errors retain caller reason/name. Stable deprecation codes are console-deduplicated while custom loggers see each warning. Direct object generation/streaming warns; unified `Output` calls suppress their internal helper warnings.

Native UI adds awaitable `stopAndWait`, `dispose` and transport `close`, cancellation-safe repeated resumes, schema/refiner-aware restored approvals and missing static-tool provenance. Successful unavailable static outputs are omitted; dynamic/error outputs and restored converters retain their distinct behavior. Browser HTTP/WebSocket wire protocols, explicit UI step boundaries and asynchronous JavaScript auto-send callback races remain deferred or runtime-specific.

MCP Events provides typed catalog/subscription adapters, atomic patch stores, direct and managed creation, callback URL validation, pending/active/expired lifecycle, identity-preserving refresh, Standard Webhooks HMAC secret rotation/timestamps, body bounds, challenge handling and durable callbacks before cursor commit. OAuth invalid_grant retries only when the failed refresh generation is available. Deprecated EventSource transport changes do not imply a native legacy-SSE adapter.

Published `provider-utils@5.0.58` still uses internal choice codes and `ai@7.0.137` strict choice-max validation. Monorepo exact-label/relaxed-rounding follow-ups are excluded. React runtime/declarations are unchanged apart from dependency propagation and remain outside this Swift-native package.

## 2026-10-04 Native Parity

Async image capability middleware; custom tool-search ranking and result limits; metadata-safe smoothing; audio usage and consumed-byte streaming telemetry; data-part conversion in agent UI streams; native partial-input resume and superseded approval filtering. Swift dictionaries and value equality already cover prototype/cross-realm fixes. Browser HTTP reconnect, raw-input UI wire-state migration, Node SSE keep-alive/response headers, diagnostics-channel instrumentation, and workflow serializers remain outside the native surface.

Async tri-state file/mask image capabilities and optional native JSON speech/transcription/stream-finish usage are exposed with defaults and retained initializer overloads.

Complete ASCII DNS-label validation, ambiguity-safe ID/index/name tool-call correlation, unique IDs for missing/reused IDs, structural argument tracking, stable mixed-index flush order, and transcription finish usage. Swift URLSession/header/environment types cover the JavaScript-only helper changes.

Typed authorization-server mismatch errors; invalidation context captures the failed refresh generation so shared stores can compare-and-delete without deleting a concurrent refresh. Swift dictionaries already isolate reserved tool names.

`SpeechResult.usage`, `TranscriptionResult.usage`, `StreamingTranscriptionFinish.usage`, and `Telemetry.Event.providerUsage` retain provider-native JSON rather than coercing audio billing units into token usage. `AI.streamTranscribe` counts chunks only when the provider consumes them. Existing initializer and iterator signatures are retained. Image flags are `Bool?` async getters: nil is unknown, and middleware may explicitly override a known flag to nil.

## Latest Core Package Diff Notes

Checked npm package diffs:

- `ai@7.0.143 -> 7.0.148`
- `@ai-sdk/provider@4.0.29 -> 4.0.31`
- `@ai-sdk/provider-utils@5.0.62 -> 5.0.65`
- `@ai-sdk/react@4.0.147 -> 4.0.152`

- `ai@7.0.137 -> 7.0.143`
- `@ai-sdk/provider@4.0.26 -> 4.0.29`
- `@ai-sdk/provider-utils@5.0.58 -> 5.0.62`
- `@ai-sdk/react@4.0.140 -> 4.0.147`


- `ai@7.0.127 -> 7.0.137`
- `@ai-sdk/provider@4.0.21 -> 4.0.26`
- `@ai-sdk/provider-utils@5.0.53 -> 5.0.58`
- `@ai-sdk/react@4.0.130 -> 4.0.140`

- `ai@7.0.117 -> 7.0.127`
- `@ai-sdk/provider@4.0.18 -> 4.0.21`
- `@ai-sdk/provider-utils@5.0.49 -> 5.0.53`
- `@ai-sdk/react@4.0.120 -> 4.0.130`

- `ai@7.0.107 -> 7.0.117`
- `@ai-sdk/provider@4.0.17 -> 4.0.18`
- `@ai-sdk/provider-utils@5.0.45 -> 5.0.49`
- `@ai-sdk/react@4.0.110 -> 4.0.120`
- `ai@7.0.99 -> 7.0.107`
- `@ai-sdk/provider@4.0.14 -> 4.0.17`
- `@ai-sdk/provider-utils@5.0.40 -> 5.0.45`
- `@ai-sdk/react@4.0.102 -> 4.0.110`
- `ai@7.0.93 -> 7.0.99`
- `@ai-sdk/provider@4.0.10 -> 4.0.14`
- `@ai-sdk/provider-utils@5.0.36 -> 5.0.40`
- `@ai-sdk/react@4.0.96 -> 4.0.102`
- `ai@7.0.85 -> 7.0.93`
- `@ai-sdk/provider@4.0.9 -> 4.0.10`
- `@ai-sdk/provider-utils@5.0.34 -> 5.0.36`
- `@ai-sdk/react@4.0.88 -> 4.0.96`
- `ai@7.0.77 -> 7.0.85`
- `@ai-sdk/provider@4.0.7 -> 4.0.9`
- `@ai-sdk/provider-utils@5.0.29 -> 5.0.34`
- `@ai-sdk/react@4.0.80 -> 4.0.88`
- `ai@7.0.68 -> 7.0.77`
- `@ai-sdk/provider@4.0.7` (unchanged)
- `@ai-sdk/provider-utils@5.0.27 -> 5.0.29`
- `@ai-sdk/react@4.0.71 -> 4.0.80`
- `ai@7.0.66 -> 7.0.68` (dependency-only)
- `@ai-sdk/react@4.0.69 -> 4.0.71` (dependency-only)
- `ai@7.0.58 -> 7.0.66`
- `@ai-sdk/provider@4.0.7` (unchanged)
- `@ai-sdk/provider-utils@5.0.25 -> 5.0.27`
- `@ai-sdk/react@4.0.61 -> 4.0.69`
- `ai@7.0.48 -> 7.0.58`
- `@ai-sdk/provider@4.0.4 -> 4.0.7`
- `@ai-sdk/provider-utils@5.0.18 -> 5.0.25`
- `@ai-sdk/react@4.0.51 -> 4.0.61`
- `ai@7.0.44 -> 7.0.48`
- `@ai-sdk/provider@4.0.4` (unchanged)
- `@ai-sdk/provider-utils@5.0.16 -> 5.0.18`
- `@ai-sdk/react@4.0.47 -> 4.0.51`
- `ai@7.0.37 -> 7.0.44`
- `@ai-sdk/provider@4.0.3 -> 4.0.4`
- `@ai-sdk/provider-utils@5.0.12 -> 5.0.16`
- `@ai-sdk/react@4.0.40 -> 4.0.47`
- `ai@7.0.31 -> 7.0.37`
- `@ai-sdk/provider-utils@5.0.11 -> 5.0.12`
- `@ai-sdk/react@4.0.34 -> 4.0.40`
- `ai@6.0.208 -> 7.0.31`
- `@ai-sdk/provider@3.0.10 -> 4.0.3`
- `@ai-sdk/provider-utils@4.0.30 -> 5.0.11`
- `@ai-sdk/react@3.0.210 -> 4.0.34`
- `ai@6.0.200 -> 6.0.208`
- `@ai-sdk/provider@3.0.10`
- `@ai-sdk/react@3.0.206 -> 3.0.210`
- `@ai-sdk/provider-utils@4.0.29 -> 4.0.30`
- `@ai-sdk/provider-utils@4.0.30 -> 5.0.1` response size-limit patch

Port decisions:

- `ai@7.0.117` has the same published runtime source as `7.0.116` and only advances `@ai-sdk/gateway`. Its sole exact-tag test delta replaces the stale `typesafe-ai/jev-latest` Gateway evaluation fixture with `typesafe-ai/jev`; Swift request tests and public Gateway examples use that current identifier.
- `ai@7.0.116` materializes HTTP(S)-backed generated file and reasoning-file
  outputs for generate, stream, and batch results while preserving opaque
  non-HTTP URI strings. URL policy, redirect validation, credential stripping,
  aborts, and response limits are shared; resolver-backed connection-address
  pinning remains an explicit platform design gap and is not implied by
  hostname validation.
- Embedding models can expose `providerOptionsTransformer` to slice per-value
  options with each automatic batch. Retries reuse the already transformed
  batch options, keeping multimodal values and provider options aligned under
  count and byte limits. Speech media detection now recognizes canonical L16,
  mu-law, and A-law output types.
- Tool approval requests retain the pre-refinement `inputSchemaInput` alongside
  the approved refined arguments. Persisted approvals re-run schema validation
  and refinement and reject either representation when it has changed; chat
  approval responses resume the assistant message that originated the request,
  even when later messages exist.
- Reasoning pruning now treats `.reasoningFile` parts like textual reasoning:
  `.all` and `.beforeLastMessage` remove both forms within their selected scope
  while leaving ordinary file content intact.
- Routed local-caller-only tools are not advertised for direct model execution.
  If a provider still emits a direct call, the facade returns a non-executing
  tool-error result; the advertised local caller remains bound and executable.
- `AIUIMessageStreamReducer.snapshots` accepts an existing `originalMessage`
  and an async single-fire `onEnd` callback. Terminal events distinguish normal
  completion, provider abort, failure, and consumer cancellation without
  inventing a successful finish for early iterator termination.
- Evaluation now supports `runtimeContext`, `onStart`, `onEnd`, and typed
  lifecycle payloads. Telemetry emits `modelCallStart`/`modelCallEnd` around
  the logical evaluation model call, carries validated answers/usage/metadata,
  and includes only runtime-context keys explicitly allowlisted through
  `Telemetry.Options.includeRuntimeContext`.
  Existing 1.9.0 call sites and stored function references remain source
  compatible through exact overloads for evaluation, UI stream snapshots,
  approval requests, Open Responses factories, and telemetry initializers.
  Exhaustive switches over `Telemetry.Event.Kind` must add handling for
  `modelCallStart` and `modelCallEnd`; this is the only intentional Swift
  source migration required by the new telemetry surface.
- `@ai-sdk/provider@4.0.18` requires no representation rewrite: Swift's
  provider-neutral file data is already a string and therefore preserves
  opaque URIs without forcing Foundation URL normalization.
- `@ai-sdk/provider-utils@5.0.49` adds the public `fetchUntrustedURL` security
  contract. Only explicitly safe first-hop headers are forwarded to untrusted
  origins; arbitrary credentials require an exact credentialed origin and are
  stripped permanently after a cross-origin redirect.
- `@ai-sdk/mcp@2.0.60` preserves caller-supplied stdio environment values,
  drops discovery protocol headers on cross-origin redirects, and distinguishes
  dynamically registered OAuth clients from pre-registered clients before
  invalidating credentials after `invalid_client` or `unauthorized_client`.
- Overlap-safe reasoning extraction tracks each text ID independently,
  preserves both reasoning and visible text, and emits globally stable
  reasoning IDs. Positioned empty system-control messages remain available to
  Responses providers for validated reasoning-effort updates.
- `@ai-sdk/react@4.0.120` has byte-identical published source and no changed exact-tag React tests relative to `4.0.119`; it only advances the `ai` dependency to `7.0.117`. The throttled completion-hook behavior introduced in `4.0.119` remains outside this framework-neutral SwiftPM package, while its portable stream cancellation behavior is represented by the native `AsyncSequence`/UI-message lifecycle above.
- `ai@7.0.107`, `@ai-sdk/provider@4.0.17`, and
  `@ai-sdk/provider-utils@5.0.45` add the experimental Evaluation V4 vertical.
  `AI.experimentalEvaluate` validates Choice, Score, and Boolean questions and
  answers, preserves rounding, usage, warnings, metadata, retries, and aborts,
  and resolves direct or registry models. OpenAI, Anthropic, Google, and
  Gateway expose provider adapters.
- Dynamic tool callers now span `generateText`, `streamText`, and
  `AIToolLoopAgent`. Local callers bind routed tools and announce their catalog
  to the model; provider callers prepare provider options; deferred tool search
  exposes matches on the next model preparation without mutating the active
  step.
- Unsupported prompt URLs are downloaded through the shared security policy
  with abort propagation. A model selected by `prepareStep` now supplies the
  provider/model identity recorded in step results, final response metadata,
  and telemetry rather than leaking the original model identity.
- Structured generation parses only the final tool-loop step, and structured
  streams discard earlier tool-step text while preserving valid `null` and
  empty-string partial outputs. Message pruning retains the originating call
  for pending approvals, and preliminary chat tool output does not trigger an
  automatic follow-up send.
- Data URLs honor explicit UTF-8 and ISO-8859-1 charsets while retaining the
  legacy byte-string fallback; media sniffing recognizes AAC, including
  ID3-prefixed ADTS. Async video polling applies its deadline to an in-flight
  status request. MCP persists authorization-server metadata and coalesces
  concurrent or late stale-token 401 responses into one refresh.
- Realtime V4 now models continuous conversation capabilities, server
  WebSocket startup/finalization, context and audio-control commands,
  acknowledgements, delegation/error correlation, usage, audio, and transcript
  events. OpenAI Live provides the portable authenticated server-WebSocket
  adapter and provider factory; browser WebRTC/client permissions,
  provider-backed Responses delegation, non-Live OpenAI Realtime, and Google
  Realtime 3.8 remain deferred.
- `ai@7.0.99` and `@ai-sdk/provider@4.0.14` move Batch V4 ownership
  from individual language models to a provider service. Swift's public batch
  foundation accepts per-request model IDs and discriminated text/image
  requests, returns typed text/image items, and exposes cancel/list alongside
  start/status/results. Compatibility shims retain the previous model-bound
  text-batch entry points.
- The current provider-owned adapters preserve each upstream capability
  boundary: Anthropic, OpenAI, and Gateway accept text requests; Google and xAI
  accept text and image requests. Gateway rejects image batches and requires a
  common model, Google requires one common endpoint model while retaining each
  request's model identity, and xAI accepts mixed model IDs.
- Image-model results retain the provider's optional retry classification.
  Empty output is retried when unclassified or explicitly retryable and remains
  terminal when a provider marks it non-retryable; all attempt calls remain
  visible. Google and Vertex content-filter prompt blocks use the terminal
  classification.
- `streamText` enforces required and named tool choices after every model step,
  including `prepareStep` overrides, with the same non-retryable violation used
  by `generateText`. Reranking also rejects nonintegral, negative, or
  out-of-range provider indexes before exposing a result.
- UI message conversion represents a provider `ToolOutputError` as a stable
  typed tool-output-error part. Video generation begins observing webhook
  receiver rejection before starting provider work so the first start/receiver
  failure is retained deterministically.
- `@ai-sdk/provider-utils@5.0.40` tightens media sniffing to the complete
  `GIF87a`/`GIF89a` headers and BMP signatures with zero reserved bytes. Swift's
  native `Data` base64 encoder already handles large payloads without the
  JavaScript array-spread limitation.
- MCP OAuth metadata discovery applies the shared URL policy before its first
  request and at every redirect, rejects private/link-local targets, permits
  loopback only for a configured local MCP origin, and never follows token or
  registration redirects carrying credentials.
- Generic callback `runtimeContext` for embeddings and reranking remains
  deferred until Swift has a typed callback-context and telemetry include-list
  design. The JavaScript `getTextFromDataUrl` error-class change likewise does
  not add a parallel public helper while Swift continues to expose its existing
  `downloadURL`/`AIDownloadError` contract.
- `@ai-sdk/react@4.0.102` changes `useChat` stream ownership around committed
  ID replacement and React Suspense. SwiftAISDK has no React hook lifecycle, so
  its framework-neutral `AIChatSession` receives no corresponding runtime
  change.
- `ai@7.0.93` adds bounded `Output.array` schemas and final-count checks,
  embedding result-count validation, image no-output call diagnostics, enforced
  required/named tool choice, batch tool content and provider metadata,
  attempt-isolated post-start stream recovery, and UI approval/message identity
  preservation. `Output.array` remains source compatible and nonthrowing at
  construction time; invalid bound combinations are rejected before model work
  when the strategy executes.
- `@ai-sdk/provider@4.0.10` expands `AIFileClient` from buffered upload to an
  optional Files V4 contract with capability discovery, single-use streamed
  upload, metadata, streamed download, deletion, and typed size/date results.
  Existing upload-only clients remain source compatible through protocol
  defaults.
- `@ai-sdk/provider-utils@5.0.36` supplies the portable transport foundations:
  validated DELETE, cancellation-safe ordered streaming multipart bodies,
  streamed binary responses, multipart escaping, and redacted error
  diagnostics. The Undici dependency patch remains JavaScript-specific.
- `@ai-sdk/react@4.0.96` changes React/browser `useObject` error-state wording
  and dependency baselines. SwiftAISDK retains its native object/chat sessions;
  no runtime behavior is copied from that framework hook.
- Structured object/array streams use the same isolated `streamRetries`
  pipeline as raw text streams. Only observed retryable in-band provider error
  chunks consume that budget; schema or decoding failures after a complete
  response remain terminal and do not trigger another model request. Already
  yielded text cannot be retracted and may repeat on the replacement attempt.
- Batch V4 now carries facade-level tools/tool choice and start/result provider
  metadata. Google is the fifth durable adapter, validates nonempty result keys,
  preserves empty-text thought signatures, and supports inline or uploaded
  JSONL requests. OpenAI validates the outer result envelope before yielding;
  xAI retains the final assistant choice's raw finish reason.
- UI conversion retains approval descriptors, restores failed-result provider
  metadata to its associated tool call, and uses an explicitly supplied
  replacement-message ID as the new transcript identity. Prior typed UI-tool
  schema and automatic denied-chat submission gaps remain unchanged.
- `ai@7.0.85`, `@ai-sdk/provider@4.0.9`, and
  `@ai-sdk/provider-utils@5.0.34` extend the Swift public core vertically:
  image results expose their underlying per-call outputs; embedding models can
  declare a UTF-8 byte budget combined with the per-call count limit; Batch V4
  accepts completion webhooks and retains full result content plus validated
  native request counts; and `AIStreamProviderError` preserves provider-owned
  type, code, HTTP status, retryability, and raw data for in-band stream
  failures.
- Manual approval requests retain an optional policy reason. Replayed approved
  calls are revalidated against the current tool schema and signature secret;
  invalid persisted input becomes a model-visible error result so the loop can
  continue without executing it. Object output parsing also avoids treating a
  mixed tool-call finish as terminal structured output while retaining valid
  text when the provider omits a finish reason.
- The current core batch alignment carries the complete language-model option
  surface into provider batches and makes webhook support explicit: Gateway
  forwards its callback URL while direct Anthropic, OpenAI, and xAI batch
  adapters return an unsupported warning. Native counts are exposed only when
  nonnegative values reconcile to the total.
- Canonical-hash preservation for JavaScript `undefined` array slots has no
  Swift `JSONValue` analogue. Stateful/empty-match JavaScript RegExp handling
  in `smoothStream`, React hook updates, and cancellation before a JavaScript
  stitchable stream registers its inner stream are runtime-specific and do not
  add Swift behavior.
- Transient body-read `URLError` values were already retryable in the shared
  Swift retry boundary. Parsed output was already emitted to `streamText` end
  callbacks, and the UI reducer already preserves active parts, so those
  upstream patches require regression evidence rather than new runtime code.
- Typed UI-tool schema conversion, automatic chat submission after a denied
  approval, operation-level UI outcomes, byte-array approval secrets, true
  image request splitting with per-call metadata, and Gateway cost aggregation
  across those split calls remain deferred. They need broader public UI/media
  contracts than the additive `ImageGenerationResult.calls` surface alone.
- `@ai-sdk/react@4.0.88` contains React hook and dependency propagation only;
  SwiftAISDK continues to expose `AIChatSession` rather than React stores.
- `ai@7.0.68 -> 7.0.77` ports every applicable core behavior: automatic tool
  execution now stops after unsafe finish reasons; preliminary tool output can
  be filtered from model-message conversion; in-band `streamObject` errors
  terminate with the provider failure; client approval stops a loop even while
  a provider result is deferred; text/reasoning stream IDs remain unique across
  steps; and `AI.startVideo` / `AI.getVideoStatus` expose direct persisted
  operation calls. Streaming callbacks are nonthrowing Swift closures, so the
  JavaScript callback-rejection failure mode is already impossible. Nullish
  branded-ID UI schema inference is TypeScript-only.
- The WorkflowAgent retry `reset-step` addition is deferred because SwiftAISDK
  has no resumable indexed WorkflowAgent chunk transport or reset-step
  producer; adding a public case without that runtime would not port the
  behavior.
- `@ai-sdk/provider-utils@5.0.29` preserves schema-valued
  `additionalProperties` recursively and normalizes empty generated/streamed
  tool-call IDs. Focused Swift tests cover both. Blob request bodies and
  fetch-less module import are JavaScript runtime concerns.
- `@ai-sdk/react@4.0.80` carries React hook/dependency changes only. SwiftAISDK
  continues to expose its native `AIChatSession`; no React-specific patch is
  applicable. `@ai-sdk/provider@4.0.7` has no version or source drift.
- `ai@7.0.68` and `@ai-sdk/react@4.0.71` contain dependency propagation only;
  their published `src` trees are unchanged from 7.0.66 and 4.0.69.
- The 2026-08-19 provider patch train advances Amazon Bedrock, Azure, Baseten,
  Cerebras, DeepInfra, Fireworks, Gateway, Google, Google Vertex, Hugging Face,
  MCP, OpenAI, OpenAI-compatible, and TogetherAI. Core-facing portable changes
  are Fireworks JSON Schema output, the Gemini 3.7 Flash `low` thinking floor,
  OpenAI Responses `allowedTools` plus the `computer` tool, MCP 2.0.33
  compatibility hardening, Bedrock EventStream failure/EOF propagation, and
  preservation of OpenAI-compatible raw usage details. The remaining package
  deltas are version, dependency, or forward-compatible model-ID propagation.
- `ai@7.0.66` array output wrappers now hoist both root `definitions` and
  `$defs`, preserving schemas whose array items reference root definitions.
  `AIChatSession` also stays `.submitted` for metadata-only response-start
  snapshots and moves to `.streaming` only when response content arrives.
- The remaining `ai@7.0.66` changes are covered or do not map to Swift:
  reasoning UI parts already retain IDs; reconnect snapshots never clone the
  previous assistant response; Swift chat inputs require no asynchronous
  browser-file preparation; every provider can be stored behind `AIProvider`
  even when reranking throws unsupported; and ToolLoop settings are already
  accepted by the runtime types. TypeScript declaration emit, React message
  cloning, and promise rejection from a JavaScript `onFinish` callback have no
  direct Swift runtime surface.
- `@ai-sdk/provider-utils@5.0.27` keeps the original streamed size-limit error
  if response cancellation also fails. Swift cancellation is not awaited on
  that error path, so it already preserves the primary failure. The safe
  module import without a global JavaScript `fetch` is likewise inapplicable.
- `@ai-sdk/react@4.0.69` changes `useChat`, `useCompletion`, and `useObject`
  hook/store behavior. SwiftAISDK exposes a native `AIChatSession` rather than
  React hooks, so no framework-specific state patch is applied.
- Provider-facing language streams now consume `AIStreamingTransport` bodies
  incrementally rather than awaiting a buffered `AIHTTPResponse`. Shared SSE
  parsing follows `eventsource-parser` chunk, line-ending, BOM, field-space,
  and incomplete-EOF behavior; Amazon EventStream parsing validates frame
  lengths and CRCs. Focused gated and loopback tests prove first-part delivery
  before EOF plus cancellation of the response body on abort or early stop.
  Custom send-only transports remain valid for unary generation and fail
  streaming with a non-retryable argument error.
- Built-in language streams use one part-aware text/reasoning lifecycle instead
  of emitting both legacy and identified deltas. The facade normalizes
  legacy-only custom streams, rejects ambiguous mixed-family streams, preserves
  repeatable in-band provider errors, and validates that a stream does not emit
  duplicate terminals for one logical response. Built-in providers guarantee
  one terminal outcome per response; clean custom EOF without a terminal is
  left unspecified rather than assigned a guessed reason. Cross-surface tests
  guard exact accumulation in text,
  reasoning, UI, structured-output, and tool-loop consumers.
- `ai@7.0.58` default instructions, agent-level default timeouts, and
  reconnect cancellation are ported through `defaultInstructionsMiddleware`,
  `AIToolLoopAgent.timeoutNanoseconds`, and `AIChatReconnectRequest.abortSignal`.
  Focused tests cover call-level system-message precedence, timeout override
  precedence, and resume-stream abort propagation.
- `@ai-sdk/provider-utils@5.0.25` streamed tool-call correlation is ported for
  both the generic tracker and OpenAI-style provider streams: non-empty IDs
  take precedence over explicit indexes, missing indexes continue the latest
  call, reused indexes can start distinct calls, and finalization happens only
  on stream flush. Generic OpenAI-compatible text-token usage is also clamped
  at zero when a provider reports more reasoning than completion tokens.
- `ai@7.0.68` and `@ai-sdk/provider@4.0.7` Batch V4 and async Video V4 are
  represented by shared Swift protocols and facades. Text batches expose
  persistable references, normalized status/counts, cancellable JSONL terminal
  result streams, and per-item failures; Anthropic Messages Batch and OpenAI
  Responses Batch provide vertical adapters. `AsyncVideoModel` exposes
  serializable start/status state, core-owned polling/webhook waiting,
  cancellation, provider-metadata merging, and one stable `idempotency-key`
  across start retries while preserving unary `VideoModel` calls. Black Forest
  Labs FLUX 3 and Fal provide operation adapters; Fal forwards a native webhook,
  BFL warns and falls back to polling, and requests above a provider's
  `maxVideosPerCall` are split into ordered logical starts.
- `@ai-sdk/react@4.0.61` changes React `useChat` subscription throttling so an
  unrelated render cannot bypass the configured cadence. SwiftAISDK has no
  `useSyncExternalStore`/React render subscription, so there is no direct
  portable runtime change.
- `ai@7.0.45` extends the experimental tool-caller graph from `generateText`
  into `streamText` and `ToolLoopAgent`. Swift still has no shared late-bound
  local/provider caller abstraction, so the existing generic tool-caller gap
  now explicitly covers all three orchestration surfaces rather than adding a
  provider-specific shortcut.
- `ai@7.0.45` streaming timeout behavior is represented by
  `AIStreamTimeoutConfiguration`: total, per-model-step,
  first-semantic-output, and inter-semantic-output deadlines are public;
  total and step budgets include retry backoff, the step signal remains active
  through client-side tool execution, and timeout aborts reach provider and
  tool signals with the `TimeoutError` reason name. Step/first/inter-chunk
  timers re-arm for every model step; metadata, lifecycle, raw keep-alives,
  tool results, and empty deltas do not reset the semantic timers. Typed
  `Output` streams accept the same configuration. `AIStreamTimeoutError`
  identifies the first-chunk or chunk phase, while the legacy flat total
  timeout remains source-compatible. The clarified `GenerateTextResult.output`
  no-output documentation matches Swift's existing `AINoOutputError` behavior.
- `@ai-sdk/provider-utils@5.0.18` centralizes empty usage and common response
  metadata construction without changing result shapes. Swift already uses
  shared `TokenUsage` and `AIResponseMetadata` conversion paths. Its switch
  from a JavaScript symbol to an `experimental_toolCaller` object property is
  part of the deferred caller abstraction above and has no standalone Swift
  representation.
- `@ai-sdk/react@4.0.47 -> 4.0.51` contains dependency/version propagation
  only; no portable React source contract changed.
- `ai@7.0.44` telemetry end events attribute the resolved response model rather
  than only the requested model ID. Swift now uses response metadata for the
  same attribution and carries focused generate/stream telemetry regressions.
- `ai@7.0.42` metadata on empty text deltas is preserved by the Swift stream
  accumulator and output mapper instead of being discarded with an empty text
  payload. `ai@7.0.38` provider-executed invalid tool calls no longer cause a
  duplicate client-side error result or execution attempt.
- `ai@7.0.42` per-`prepareStep` call-setting overlays remain deferred. Swift can
  return a replacement request, but currently persists that request into later
  steps; faithful parity needs an isolated validated overlay and matching
  telemetry for each model call.
- `ai@7.0.43` generic provider tool-callers remain deferred. OpenAI and
  Anthropic wire formats already accept manual allowed-caller provider options,
  but automatic tool-owned caller registration needs one late-binding core
  contract rather than provider-specific shortcuts.
- `@ai-sdk/provider@4.0.4` and `ai@7.0.38` add experimental streaming speech
  translation. Swift now has reusable `AIDuplexWebSocketTransport`, streaming
  audio input, lifecycle/result/error types, a Cartesia Ink 2 streaming
  transcription adapter, and provider-neutral `AIRealtimeModelV4`/
  `AIRealtimeSession` contracts with xAI as the first full Realtime V4 adapter.
  Google/OpenAI translation, ElevenLabs realtime transcription, and full
  non-xAI speech-session adapters still need provider-specific translations
  above those shared contracts.
- `@ai-sdk/provider-utils@5.0.16` adds resolver-backed DNS address validation
  and connection pinning. Swift still validates literal/private hosts and every
  redirect, but URLSession does not expose the same connector hook; DNS
  rebinding protection is therefore recorded as a transport-level gap rather
  than claimed as covered. Workflow serialization and JavaScript WebSocket
  helper changes have no direct Swift runtime surface.
- `@ai-sdk/react@4.0.40 -> 4.0.47` is dependency/version propagation only; no
  portable React source contract changed.
- `ai@7.0.36` injective tool-approval signatures are ported through
  `toolApprovalSecret`: Swift signs the versioned JSON-array payload, accepts
  safe legacy newline-format signatures only when the signed identity fields
  contain no newline, and rejects delimiter retupling. Canonical JSON matches
  ECMAScript `JSON.stringify` and UTF-16 object-key ordering, including numeric
  exponent thresholds, `-0`, and large integral doubles, so Node and Swift
  signatures remain interoperable. Focused tests cover published Node vectors,
  Unicode key ordering, control characters, legacy compatibility, and the
  original collision.
- `ai@7.0.33` consecutive tool-message provider options are represented by
  Swift provider metadata. When tool messages are combined, the earlier
  message metadata is deep-merged into its boundary content part, with
  part-level values winning, while the later message metadata remains on the
  combined message.
- `ai@7.0.32` multi-step non-streaming generation now rechecks the caller abort
  signal before every later model step. Cancellation during tool execution
  preserves the original `AIAbortError` reason and prevents a second model
  call even when the tool returns normally.
- `@ai-sdk/provider-utils@5.0.12` media sniffing is ported: ID3-prefixed raw and
  base64/base64url inputs decode only a bounded prefix, optional base64 padding
  is restored, the 128 KiB tag boundary matches upstream, and ISO-BMFF `ftyp`
  bytes resolve to `audio/mp4` in an audio context while generic detection keeps
  the ambiguous container as `video/mp4`.
- `ai@7.0.35` `stepMs`, `firstChunkMs`, and semantic-content-only `chunkMs`
  behavior is ported through `AIStreamTimeoutConfiguration`, including
  per-model-step re-arming and timer cleanup on normal completion, provider
  failure, timeout, and consumer cancellation.
- `ai@7.0.33` repeated tool-call ids across explicit UI stream steps are
  deferred. `AIUIMessageStreamReducer` currently indexes tool parts globally,
  and `LanguageStreamPart` has no `start-step` / `finish-step` cases from which
  to define the upstream step boundary without a broader public stream change.
- `ai@7.0.35` Node `ServerResponse` piping promises and read/write error
  propagation remain JS-server-only. `ai@7.0.32` loose Zod UI-message chunk
  schemas likewise have no direct Swift patch because SwiftAISDK exposes typed
  in-process `LanguageStreamPart` values rather than that Zod wire decoder.
- `ai@7.0.12` response-message tool-result ordering is ported in
  `toResponseMessages`: non-provider-executed tool results are sorted by the
  original tool-call order while approval responses keep their relative slots.
- `ai@7.0.12` `extractJsonMiddleware` streamed suffix whitespace fix is not a
  separate Swift runtime patch because SwiftAISDK buffers per text block before
  applying the transform; the upstream partial-stream boundary that caused the
  bug is not exposed.
- `ai@7.0.7` `convertToModelMessages` empty-assistant fix and `ai@7.0.5`
  orphaned approval-response pruning are already covered by upstream-style
  Swift regression tests.
- `@ai-sdk/provider@4.0.3` ProviderV4 additions are represented by Swift's
  existing stable protocols: provider references, file uploads, custom content,
  reasoning files, top-level reasoning, tool-result file content, video
  `frameImages`/`inputReferences`, and `generateAudio` request fields. The
  ProviderV4 type names, ESM packaging, and Node 22 engine requirement are
  JavaScript-only concerns.
- `@ai-sdk/provider-utils@5.0.11` security/runtime changes were audited against
  Swift transports and parsers. Response-size limits, same-origin credential
  hardening, SSRF download validation, typed JSON parsing, and body cancellation
  semantics are covered or Swift-native. Redirects are followed manually,
  every hop is validated before use, same-origin provider credentials are kept,
  and cross-origin provider credentials are removed. JavaScript
  prototype-pollution fixes are not applicable to Swift value dictionaries.
- `@ai-sdk/provider-utils@5.0.11` and `ai@7.0.14` streaming transcription are
  represented by `StreamingTranscriptionModel`, `StreamingTranscriptionPart`,
  `AIStreamingAudioInput`, and the injectable duplex WebSocket transport, with
  Cartesia Ink 2 as the first vertical adapter. Realtime session/media
  negotiation is represented separately by `AIRealtimeModelV4` and
  `AIRealtimeSession`; xAI is the first provider adapter, while full non-xAI
  realtime remains deferred.
- `@ai-sdk/openai@4.0.43` Responses `allowedTools` resolves declared function,
  built-in, MCP, custom, and current computer tools to upstream allow-list
  entries, warns for entries that cannot be represented, and rejects an
  allow-list that becomes empty. `OpenAITools.computer()` is distinct from the
  older `computerUse(...)` wire tool. `@ai-sdk/open-responses@2.0.28` remains
  intentionally narrower: provider-defined tools warn and are dropped, matching
  upstream rather than inventing an execution contract.
- `@ai-sdk/mcp@2.0.33` is represented by the current MCP client, HTTP/SSE and
  stdio transports, tool conversion, and OAuth helpers. The patch is treated as
  protocol/transport and OAuth compatibility hardening; product-facing details
  stay documented conservatively until the complete source vertical is settled.
- `@ai-sdk/react@4.0.34 -> 4.0.40` has no direct source or declaration diff.
  Its releases only propagate `ai`, provider-utils, gateway, and MCP dependency
  updates. SwiftAISDK's UI analog remains `AIChatSession`,
  `AIObjectGenerationSession`, `DirectAIChatTransport`, and
  `AIUIMessageStreamReducer`; there is no React iframe renderer to port.
- `provider-utils@4.0.30` SSRF hardening is ported in `validateDownloadURL`
  and `downloadURL`: trailing-dot hostnames are normalized before local-host
  checks, additional private/reserved IPv4 and IPv6 ranges are blocked,
  embedded IPv4-in-IPv6 forms are decoded, and redirects are followed manually
  with each hop validated before the next request is issued.
- `provider-utils@4.0.30` same-origin credential hardening is ported through the
  shared `isSameOrigin` helper and provider-specific guards for
  Black Forest Labs, FAL, Fireworks, Gladia, Google Veo, and Replicate.
- `provider-utils@5.0.1` response-handler memory hardening is ported at the
  Swift transport boundary: `URLSessionTransport.send` now applies
  `AIDefaultMaxDownloadSize` even when a request does not pass an explicit
  `maxResponseBytes`, so buffered JSON/error responses are rejected from
  `Content-Length` or while streaming before unbounded accumulation.
- `ai@6.0.201` array-output transform fix is already Swift-native: array output
  returns decoded `Element` values from the final validated object array path,
  and Swift has no Zod-style transform pipeline that could return raw elements.
- `ai@6.0.202` approval replay HMAC is no longer a documented Swift gap. The
  current signed replay path is covered by the `ai@7.0.36` injective-payload
  implementation described above.
- `ai@6.0.203` stream-part prototype-pollution hardening is not directly
  applicable to Swift value dictionaries and typed reducers; related stream
  accumulators are keyed by Swift `String`/`Int` values without JS prototype
  inheritance.
- `ai@6.0.203` UI-message server error redaction is a JS response-stream
  default. Swift has no `createUIMessageStream` server helper; local
  `AIUIMessageStreamReducer` wraps unexpected reducer errors as
  `AIUIMessageStreamError` for in-process callers rather than serializing a
  public client error chunk.


## Reviewed 2026-11-14 delta

Extraction V4 is a distinct typed contract with nullable named fields, guesses,
confidence/source metadata, all-answer validation/refusal failures, retries and
abort-aware evidence downloads. OpenAI/Anthropic use the language-backed adapter
(Anthropic splits at 16 fields); Google uses the same language-backed extraction contract. Registries
and custom fallback providers route it. The compatibility string overload uses
the configured default provider; Gateway has no extraction factory.

Native UI adds an opt-in observable message queue, per-message options, approval
ordering, pause/resume and history-reset behavior. Automatic-send predicates remain
synchronous. Validation stops at the first invalid message/part/citation and
bounds invalid metadata errors. Tool errors preserve model history by default,
with explicit display redaction and later-reasoning compatibility warnings.
Provider-executed error codes bypass application redaction. Browser wire chunks,
React/DOM rendering, MCP iframes and Promise-specific callback scheduling remain
platform-only. ModelCapability gains extraction; existing public selectors are
retained. See WeeklyUpstreamAudit20261114 for the package-by-package evidence.
