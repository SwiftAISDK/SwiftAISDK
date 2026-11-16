# Porting Status

Snapshot date: 2026-11-15

SwiftAISDK ports the provider-facing parts of Vercel AI SDK into SwiftPM
packages: a Swift-native facade, provider registry, provider implementations,
generated provider capability docs, upstream-shaped parity tests, and a static
documentation site. The repository is distributed under Apache-2.0; the
complete terms are in the root `LICENSE` file.

This page describes the current state only. Dated pass narratives and the
provider-state journal are in
[Docs/Archive/PortingStatusHistory.md](Archive/PortingStatusHistory.md); read
them only when investigating an earlier pass.

## Release State

- 57 tracked npm packages map to 55 independent Swift packages: core, 52
  provider adapters, MCP and UI. All are published.
- SwiftAISDK 3.5.0 is the current optional compatibility umbrella. Its tested
  dependency selection is `Releases/umbrella/3.5.0.json`.
- The latest weekly pass is recorded in
  [WeeklyUpstreamAudit20261115.md](Archive/WeeklyUpstreamAudit20261115.md), with
  release evidence in
  [ReleaseVerification20261115.json](Archive/ReleaseVerification20261115.json).
- The later `parity-repairs-20261115` set (`Releases/sets/parity-repairs-20261115.json`)
  publishes Prodia, Rev.ai and Together AI 1.2.0 with their reviewed upstream
  tests translated; its public consumer evidence is
  [PublicConsumerVerificationParityRepairs20261115.json](Archive/PublicConsumerVerificationParityRepairs20261115.json).
- The 2026-11-16 upstream behavior parity audit compared every package except
  Prodia, Rev.ai and Together AI (audited the day before) with its reviewed npm
  source and matching-release tests, fixed the divergences it found and
  translated the covering upstream tests. Its 44 minor releases, including
  core 1.6.0, are published as `Releases/sets/upstream-parity-20261116.json`
  with public consumer evidence in
  [PublicConsumerVerification20261116.json](Archive/PublicConsumerVerification20261116.json);
  findings and the cases still untranslated are in
  [UpstreamParityAudit20261116.md](Archive/UpstreamParityAudit20261116.md).
- Paid/live provider checks remain disabled by default.

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
- Public docs live in `README.md` and `docs-site`; see `Docs/ProductDocumentation.md`.

## Baselines

| Area | Source of truth |
| --- | --- |
| Provider npm baselines | `Docs/ProviderVersionLedger.md` |
| Provider capabilities | `Porting/packages.json`, generated into `Docs/ProviderCapabilityMatrix.md` |
| Core AI SDK parity | `Docs/CoreV6Parity.md` |
| Upstream test inventory | `Docs/UpstreamTestInventory.md` |
| Latest pass dispositions and retained gaps | `Docs/Archive/WeeklyUpstreamAudit20261115.md` |

## Active Product Gaps

| Priority | Gap | Next action |
| --- | --- | --- |
| P1 | Standalone Google transcription/speech translation and Open Responses extension codecs remain absent native products. Vertex Gemini unary/Live transcription is implemented. | Design and port each remaining complete request/stream/replay surface before advertising parity. |
| P0 | Completion evidence can drift as npm packages and upstream tests change. | Before release, rerun package discovery, regenerate upstream inventory, compare ledgers, run `node Scripts/test-packages.mjs`, and record the audit in `Docs/Archive/`. |
| P0 | Live verification is representative, not exhaustive. | Add opt-in live smoke only for distinct transport families or concrete production risks. Keep it disabled by default. |
| P2 | Native Anthropic Messages ends and cancels its body at the first message_stop; the JS codec can consume multiple messages in one body. | Keep the existing single-response cancellation contract. A future multi-message session needs an explicit lifecycle/EOF mode and independent cleanup tests. |
| P2 | The URLSession byte adapter is now demand-driven, but still produces one Data value per byte; Foundation and higher-level parser/tool-loop buffers do not have a whole-facade memory bound. | Use the offline memory probe before a separate chunked-delegate or low-memory API design; retain injected-session compatibility and cancellation behavior. |
| P1 | xAI, OpenAI Live, Google and Gateway native WebSocket sessions are represented. Browser WebRTC/client permissions, provider-backed Responses delegation, non-Live OpenAI Realtime, ElevenLabs realtime STT and streaming translation remain deferred. | Extend `AIRealtimeModelV4` one complete transport/provider vertical at a time; do not advertise browser or delegation modes until their native lifecycle is implemented and tested. |
| P1 | Batch V4 has Anthropic, OpenAI Responses, Gateway, Google, and xAI adapters. Async Video V4 has Black Forest Labs, Fal, ByteDance, Gateway, Topaz and HeyGen adapters, but other capable providers still use unary or internal-polling paths. | Migrate additional batch/video providers incrementally when persisted operation state, native webhook behavior, and provider-specific cancellation semantics can be translated with focused tests. |
| P1 | Browser HTTP/WebSocket chat framing, Node stream-response helpers, tracing-channel/workflow codecs and legacy EventSource SSE are not native adapters. | Add a complete native public adapter only after lifecycle, replay, auth and serialization behavior are designed and tested. |
| P1 | Upstream preserves repeated tool-call IDs across explicit UI stream steps; Swift stream parts do not expose step boundaries. | Add a public step-boundary representation, then scope reducer tool-part identity to the active step with backwards lookup for late results. |
| P1 | The nonoptional Swift stopSequences array cannot distinguish omitted from explicitly empty input for Bedrock warning parity. | Introduce an additive presence-aware request representation before changing this warning behavior. |
| P1 | Provider option ergonomics are harder to discover than the core facade. | Add compact provider option examples to docs-site for non-obvious schemas and Swift differences. |
| P1 | Tooling is broad but can be more polished. | Improve validation diagnostics, typed result/error surfaces, and provider-defined tool helper docs. |
| P1 | Structured output works, but schema ecosystem parity is intentionally Swift-native. `Output.array` construction remains nonthrowing for source compatibility; invalid bounds are rejected at execution before model work begins. | Keep improving schema adapter ergonomics, repair telemetry, provider-specific structured-output examples, and docs. |
| P1 | The 2026-11-16 parity audit left known differences: tool declaration order is lost (`request.tools` is a dictionary); `embedMany` chunks run sequentially; loops stop on pending deferred provider tool results; `AIAPICallError.responseBody` holds the provider message instead of the raw body; `getFromAPI`/`deleteFromAPI` do not follow redirects; provider user-agent suffixes replace the default instead of appending; Gateway resolves credentials once per provider. Many large upstream snapshot suites (OpenAI, Anthropic, Bedrock, Google, xAI) are still untranslated. | Work through the audit's reported items one at a time with translated upstream tests; extend snapshot coverage package by package. |
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
- Focused package tests and `node Scripts/test-packages.mjs` pass, or skipped
  verification is explicitly recorded.
- The pass record is written to `Docs/Archive/` and linked from the table above.
