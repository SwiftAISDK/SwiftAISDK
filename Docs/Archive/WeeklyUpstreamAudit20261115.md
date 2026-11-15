# Weekly upstream audit — 2026-11-15

Runtime, matching-release delta review and all required local checks are complete.
The 36 independent releases passed exact-source hosted CI and public-reference checks.
SwiftAISDK 3.4.0 and its actual-tag clients are also verified. This is a delta review with retained
native/platform gaps; it does not certify full-package or live-service parity.

Fresh npm registry: 54 previously tracked packages, 36 changed versions; three
previously discovered providers are now fully implemented, giving 57 tracked
packages in 55 Swift units. Exact prefix enumeration returned 96 scoped names;
search returned 76. All 97 published mentioned/discovered packages were checked;
four documentation placeholders returned 404. The 36 changed-package preparations
verified 72 archives and 1,311 exact release-test files without fallback. The
three initial provider ports have separate full matching-release evidence. Forty
other packages were inspected as JS frameworks, tooling/workflow products or seeds.

## Package decisions

| Package | Previous reference | Latest | Decision |
| --- | --- | --- | --- |
| `@ai-sdk/alibaba` | 2.0.90 | 2.0.91 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/amazon-bedrock` | 5.0.141 | 5.0.142 | Stop rewriting thinking.block_binding.prefix_mismatch_behavior in unary and streaming InvokeModel. Preserve the original legacy public transform helper for existing direct callers. The model ID/catalog reorganization preserves existing capabilities. |
| `@ai-sdk/anthropic` | 4.0.104 | 4.0.105 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/anthropic-aws` | 2.0.97 | 2.0.98 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/assemblyai` | 3.0.82 | 3.0.82 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/azure` | 4.0.125 | 4.0.126 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/baseten` | 2.1.70 | 2.1.71 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/black-forest-labs` | 2.0.84 | 2.0.85 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/bytedance` | 2.0.85 | 2.0.86 | Published source/declarations and exact tests unchanged; retain intentional native request identity and no Swift release. |
| `@ai-sdk/cartesia` | 3.0.76 | 3.0.76 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/cerebras` | 3.0.92 | 3.0.93 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/cohere` | 4.0.83 | 4.0.84 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/deepgram` | 3.1.53 | 3.1.53 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/deepinfra` | 3.0.92 | 3.0.93 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/deepseek` | 3.0.86 | 3.0.87 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/elevenlabs` | 3.0.86 | 3.0.86 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/fal` | 3.0.83 | 3.0.84 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/fish-audio` | 3.0.59 | 3.0.59 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/fireworks` | 3.0.95 | 3.0.96 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/gateway` | 4.0.145 | 4.0.146 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/gmicloud` | 3.0.63 | 3.0.64 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/gladia` | 3.0.82 | 3.0.82 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/google` | 4.0.120 | 4.0.121 | Map Interactions top-level reasoning to model effort with explicit provider precedence and compatibility warnings; include custom reasoning in dropped agent settings. Always emit stream-start, including empty warnings. Preserve caller headers without injecting an obsolete Api-Revision. Exact release JSON/chunk fixtures are retained and Git-blob verified. |
| `@ai-sdk/google-vertex` | 5.0.140 | 5.0.141 | Derive TypeScript IDs from existing catalogs, add explicit Hydrogen catalog registration. Existing Swift open model IDs and Gemini4 gates already cover Hydrogen; preserve native behavior and synchronize versioned request identity. |
| `@ai-sdk/groq` | 4.0.83 | 4.0.84 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/heygen` | 3.0.24 | 3.0.25 | Implement complete multimodal native Decision V4 alongside existing video: boolean/choice/score, ordered image/video assets, request limits, exact error/response validation, confidence/JSON legends/warnings/usage and lazy request-time credentials. All 59 owning tests pass, including old video cases. Existing throwing initializer and video selectors preserved; legacy settings factory now also forwards decisions and retains its old credential timing/request identity. |
| `@ai-sdk/huggingface` | 2.0.92 | 2.0.93 | Derived TypeScript model IDs preserve existing native String IDs and request behavior; retain intentional native request identity and no Swift release. |
| `@ai-sdk/hume` | 3.0.81 | 3.0.81 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/klingai` | 4.0.84 | 4.0.85 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/lmnt` | 3.0.36 | 3.0.36 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/luma` | 3.0.83 | 3.0.84 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/mcp` | 2.0.99 | 2.0.99 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/minimax` | 3.0.81 | 3.0.82 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/mistral` | 4.0.86 | 4.0.87 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/moonshotai` | 3.0.92 | 3.0.93 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/open-responses` | 2.0.87 | 2.0.87 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/openai` | 4.0.117 | 4.0.118 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/openai-compatible` | 3.0.92 | 3.0.92 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/perplexity` | 5.0.34 | 5.0.35 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/prodia` | 2.0.83 | 2.0.84 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/quiverai` | 2.0.83 | 2.0.83 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/replicate` | 3.0.83 | 3.0.84 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/revai` | 3.0.81 | 3.0.81 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/togetherai` | 3.0.93 | 3.0.94 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/topaz` | 3.0.28 | 3.0.28 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/typesafe-ai` | 3.0.40 | 3.0.40 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/vercel` | 3.0.30 | 3.0.30 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/voyage` | 2.0.82 | 2.0.83 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/xai` | 5.0.45 | 5.0.46 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `@ai-sdk/zai` | 3.0.54 | 3.0.55 | Reviewed derived TypeScript model IDs and published catalogs; retain native open String model IDs, runtime request/response/options/errors/stream/telemetry behavior and synchronize existing versioned request identity. |
| `ai` | 7.0.172 | 7.0.173 | Fix double refinement of signed historical tool approvals and add three explicit-secret streaming overloads while preserving all old selectors. Native per-video descriptors preserve mixed MIME associations through fan-out. Original upstream counter/signature fixtures exercise unary and streaming replay. UI bounded validation scenarios are translated with explicit typed/JS shape differences; no UI runtime change or release. |
| `@ai-sdk/provider` | 4.0.38 | 4.0.38 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/provider-utils` | 5.0.81 | 5.0.81 | Fresh registry version equals reviewed baseline; retain current native behavior, provenance and existing documented gaps. |
| `@ai-sdk/react` | 4.0.176 | 4.0.177 | Published source/declarations and exact release tests unchanged; only dependency/package/version bundle metadata advances. Existing native UI coverage retained without a UI release. |

## Initial provider ports

| Provider | Upstream | Swift unit | Owning tests | Portable surface |
| --- | --- | --- | --- | --- |
| Tencent | 3.0.3 | swift-ai-tencent 1.0.0 | 25 / 4 suites | TokenHub chat/stream, Kling video, TC3 VOD start/status, per-file media types |
| Parallel | 3.0.9 | swift-ai-parallel 1.0.0 | 19 / 3 suites | Web-grounded Decision V4, refusal, citations/excerpts, full-precision metadata |
| ScaleDown | 3.0.1 | swift-ai-scaledown 1.0.0 | 23 / 3 suites | Decision and text/list-text Extraction V4, documents, verified UTF-16/OCR sources |

New HeyGen Decision V4 is part of the existing provider unit; all 59 owning tests
passed alongside preserved video tests. Its release is minor. Core 1.5.0 adds
explicit signed-stream overloads and per-video descriptors while retaining old
selectors/initializers. The original counter fixture first exposed execution of
3 after approving 2; the fixed path executes the validated approved input once.

## Swift release selection

Only 36 runtime-changed units are selected: 31 patch updates, two additive minor
releases (core and HeyGen), and three initial units. npm baselines and Swift
SemVer are independent. ByteDance, Hugging Face, UI, MCP and the other unchanged
units are retained. An umbrella release is separately required for the new
compatibility API and core minimum, and follows verified dependency publication.

## Explicit limits and exclusions

Inception, SpaceXAI, specification and tools 0.0.0 are implementation-free seeds.
They expose no portable provider behavior and have no Swift scaffold/release.
Browser media/WebRTC/iframes, JS framework hooks/workflows/harnesses, separate
Google audio surfaces, Gateway incremental binary-image decoding and Open
Responses extension codecs retain their documented product gaps. Swift immutable
JSON/typed UI unions cannot express JS mutation/getter/invalid union shapes;
per-scenario native equivalents and exclusions are recorded explicitly. Existing
legacy settings selectors retain their documented native credential timing and
request identity. Paid/live provider checks are disabled.

The [structured audit](WeeklyUpstreamAudit20261115.json) records every changed
published source/declaration/test file, exact archive/test provenance, native
changes, fixture hashes, package-local scenario ledgers and verification state.

## Local validation

All 55 owning package suites passed (2,451 tests across their targets), followed
by 1,736 compatibility tests. Tooling passed 27/27; generation, core/provider
isolation and version identities passed. Documentation check reported no errors,
warnings or hints and the normal site build generated 104 pages.

All 55 deterministic standalone exports passed their owning tests and 112 local
minimum/latest/mixed/compatibility consumers. Exact version-specific historical
graphs supplement the generic resolver, and one additional complete umbrella
consumer verifies the least permitted 55-dependency graph. The umbrella requires
Core 1.5.0 and HeyGen 1.2.0 for the added compatibility APIs. These local synthetic
refs are rehearsal evidence; actual public-tag checks follow publication.

## Verified independent releases

Canonical source: `1e543b35e0259a5bda888665dacf2d4a7f1bb0ed`; [Swift 6.3.3/iOS/examples/docs CI](https://github.com/SwiftAISDK/SwiftAISDK/actions/runs/43674303677). All 36 standalone CI runs and 62 clean actual-public-tag consumers passed. The complete refs and SemVer rationale are in [ReleaseVerification20261115.json](ReleaseVerification20261115.json). No unchanged Swift unit was released.

| Swift unit | Previous | Published | Change |
| --- | --- | --- | --- |
| swift-ai-core | 1.4.0 | [1.5.0](https://github.com/SwiftAISDK/swift-ai-core/releases/tag/1.5.0) | minor |
| swift-ai-alibaba | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-alibaba/releases/tag/1.1.3) | patch |
| swift-ai-anthropic | 1.4.0 | [1.4.1](https://github.com/SwiftAISDK/swift-ai-anthropic/releases/tag/1.4.1) | patch |
| swift-ai-openai | 1.3.0 | [1.3.1](https://github.com/SwiftAISDK/swift-ai-openai/releases/tag/1.3.1) | patch |
| swift-ai-amazon-bedrock | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-amazon-bedrock/releases/tag/1.1.3) | patch |
| swift-ai-anthropic-aws | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-anthropic-aws/releases/tag/1.2.2) | patch |
| swift-ai-deepseek | 1.2.0 | [1.2.1](https://github.com/SwiftAISDK/swift-ai-deepseek/releases/tag/1.2.1) | patch |
| swift-ai-azure | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-azure/releases/tag/1.2.2) | patch |
| swift-ai-baseten | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-baseten/releases/tag/1.1.3) | patch |
| swift-ai-black-forest-labs | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-black-forest-labs/releases/tag/1.1.3) | patch |
| swift-ai-cerebras | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-cerebras/releases/tag/1.2.2) | patch |
| swift-ai-cohere | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-cohere/releases/tag/1.2.2) | patch |
| swift-ai-deepinfra | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-deepinfra/releases/tag/1.1.3) | patch |
| swift-ai-fal | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-fal/releases/tag/1.1.3) | patch |
| swift-ai-fireworks | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-fireworks/releases/tag/1.1.3) | patch |
| swift-ai-gateway | 1.3.0 | [1.3.1](https://github.com/SwiftAISDK/swift-ai-gateway/releases/tag/1.3.1) | patch |
| swift-ai-gmicloud | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-gmicloud/releases/tag/1.1.3) | patch |
| swift-ai-google | 1.3.0 | [1.3.1](https://github.com/SwiftAISDK/swift-ai-google/releases/tag/1.3.1) | patch |
| swift-ai-google-vertex | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-google-vertex/releases/tag/1.2.2) | patch |
| swift-ai-groq | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-groq/releases/tag/1.2.2) | patch |
| swift-ai-heygen | 1.1.2 | [1.2.0](https://github.com/SwiftAISDK/swift-ai-heygen/releases/tag/1.2.0) | minor |
| swift-ai-klingai | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-klingai/releases/tag/1.1.3) | patch |
| swift-ai-luma | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-luma/releases/tag/1.1.3) | patch |
| swift-ai-minimax | 1.3.0 | [1.3.1](https://github.com/SwiftAISDK/swift-ai-minimax/releases/tag/1.3.1) | patch |
| swift-ai-mistral | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-mistral/releases/tag/1.2.2) | patch |
| swift-ai-moonshotai | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-moonshotai/releases/tag/1.1.3) | patch |
| swift-ai-parallel | initial | [1.0.0](https://github.com/SwiftAISDK/swift-ai-parallel/releases/tag/1.0.0) | initial |
| swift-ai-perplexity | 1.2.0 | [1.2.1](https://github.com/SwiftAISDK/swift-ai-perplexity/releases/tag/1.2.1) | patch |
| swift-ai-prodia | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-prodia/releases/tag/1.1.3) | patch |
| swift-ai-replicate | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-replicate/releases/tag/1.1.3) | patch |
| swift-ai-scaledown | initial | [1.0.0](https://github.com/SwiftAISDK/swift-ai-scaledown/releases/tag/1.0.0) | initial |
| swift-ai-tencent | initial | [1.0.0](https://github.com/SwiftAISDK/swift-ai-tencent/releases/tag/1.0.0) | initial |
| swift-ai-togetherai | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-togetherai/releases/tag/1.1.3) | patch |
| swift-ai-voyage | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-voyage/releases/tag/1.1.3) | patch |
| swift-ai-xai | 1.2.1 | [1.2.2](https://github.com/SwiftAISDK/swift-ai-xai/releases/tag/1.2.2) | patch |
| swift-ai-zai | 1.1.2 | [1.1.3](https://github.com/SwiftAISDK/swift-ai-zai/releases/tag/1.1.3) | patch |

## Verified compatibility umbrella and M3 runner

[SwiftAISDK 3.4.0](https://github.com/SwiftAISDK/SwiftAISDK/releases/tag/3.4.0) is an additive compatibility release
at `a6c2f8f456616460c1798e75e62e9552538362b9`. The 55-version selection is
recorded in [Releases/umbrella/3.4.0.json](../Releases/umbrella/3.4.0.json). Actual
3.4.0 and preserved 2.8.1 clients passed separately; the immutable 62-client
modular report remains unchanged.

[Complete M3 Swift 6.3.3 CI](https://github.com/SwiftAISDK/SwiftAISDK/actions/runs/43678851385)
passed 4,187 reported tests, iOS compilation and examples. A separate controlled
outage verified the 90-second queued-job handoff to hosted macOS; the dedicated
service was restored and Viscacha remained unchanged. See
[M3RunnerVerification20261115.json](M3RunnerVerification20261115.json).

Final documentation/tooling/deployment [CI](https://github.com/SwiftAISDK/SwiftAISDK/actions/runs/43680561085) passed at
`8f691f7fb7e935f3455e91c5142919fc63f4fe46`. Main Zen readback verified 3.4.0 installation
and current Tencent, ScaleDown and HeyGen guides, including the Extraction
capability label. Temporary verification tabs were closed. Subsequent proof-only
commits change no SDK, manifest, release selection or deployed site input.
