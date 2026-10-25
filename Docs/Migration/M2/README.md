# M2: core boundaries

Date: 2026-10-25. Status: **complete**. Next stage: M3.

The [migration plan](../../ModularizationPlan.md) now has an independently
buildable local core package. This stage does not release packages or move the
GitHub repository. The reviewed npm baselines and all 54 capability rows remain
unchanged. M0/M1 artifacts remain frozen historical records.

## Extracted runtime

| Module | Swift files | Dependencies |
| --- | ---: | --- |
| SwiftAIProvider | 29 | Foundation; no other SDK module |
| SwiftAITransport | 10 | SwiftAIProvider |
| SwiftAIProviderUtilities | 22 | SwiftAIProvider, SwiftAITransport |
| SwiftAI | 61 | All three lower modules |

The root `SwiftAISDK` target depends on these four products. Concrete providers,
MCP and UI still compile in the temporary aggregate. Core has no external package
dependency and does not import the aggregate. The catalog validates the declared
acyclic module graph; the isolated consumer verifies the actual build boundary.

The [extraction map](extraction-map.json) records all 311 original files and
current destinations, plus hashes of all 333 current runtime files. It identifies
removed import-only source anchors. These files contained no implementation.
The current package maps own every source, test and fixture; coarse upstream test
associations remain inventory evidence, not new parity claims.

## Boundary decisions

- Protocol/value closures live in contracts. Shared JSON parsing, callbacks and
  stream cancellation values no longer depend on orchestration or provider code.
- `AIProviderHTTPClient` contains neutral request construction and transport
  injection. The mixed `ProviderSettings`, `ModelHTTPConfig`, provider error
  policies and media/file adapters remain in the aggregate for provider stages.
- HTTP exposes generic API errors. The aggregate preserves Gateway error parsing
  through its internal `compatibilityAPICallError` adapter; Gateway error values
  remain contracts because `AIError` exposes them.
- Generic transcription/usage conversion lives in utilities; concrete provider
  transcription parsers remain with the aggregate. Security, DNS pinning, response
  size limits, multipart streaming and demand-driven bodies remain transport code.
- `SwiftAI.AI` has direct-model orchestration and explicit registries. There is no
  implicit provider initialization. Core custom-provider aliases can use explicit
  resolver closures; unresolved model IDs otherwise produce typed errors.
- `SwiftAISDK.AI`, `SwiftAISDK.AIProviders` and `SwiftAISDK.AICustomProvider` preserve
  legacy entry points. Their forwarding code is derived from core signatures by
  the development-only SwiftSyntax tool. Default-provider and Gateway lookup stay
  in the aggregate and run at lookup time, preserving `withProvider` behavior.
  The four small legacy global `customProvider` overloads stay in the aggregate
  to avoid ambiguous re-exported functions. Core users construct `AICustomProvider`
  or use `AIProviders.customProvider`.
- Package-internal orchestration helpers use `package`; helpers needed by the
  future independently compiled adapters are public. Networking internals such as
  DNS response readers remain internal. The complete capability inventory stays
  in the aggregate, so contracts do not embed all provider descriptors.
- Existing batch raw-finish-reason normalization is retained, including its xAI
  provider-ID check. It is a compatibility rule in the facade, not a dependency on
  an xAI implementation. This stage does not redesign result semantics.

Re-exports use Swift's existing `@_exported import` facility; this underscored
compiler feature remains a compatibility-layer dependency. A client importing
both facade modules should qualify the namespace (`SwiftAISDK.AI` or `SwiftAI.AI`).
No binary compatibility is claimed across moved modules.

## Verification

All execution below is local Swift 6.4 / macOS arm64. Counts include Swift
Testing's reported skipped cases; 33 live-provider checks were explicitly skipped.

| Check | Result |
| --- | --- |
| Focused compatibility/default-provider/Gateway tests | 88 tests, 7 suites, zero failures |
| Full aggregate suite | 3419 tests, 65 suites, zero failures; 33 explicit live skips |
| Standalone core suite | 126 tests across four test targets, zero failures |
| Baseline test preservation | Original 3543 tests retained across aggregate/core, plus two normal-import legacy consumer tests; total 3545 |
| Isolated core consumer | A copy outside the repository builds/runs with only core; custom model, registry, generation, canonical stream, tool and abort verified |
| Existing consumer examples | All 19 executable targets build; offline OAuth example reports `MCP_OAUTH_MIGRATION_OFFLINE_OK` |
| Public symbols | All 6762 M0 records matched against 7020 current graph records after demangling and module normalization; zero unmatched records |
| Catalog/generation/tooling | 52 packages, only core marked extracted; deterministic outputs; 9 tests including unchanged upstream/capability baseline and generated-surface failure detection |
| Documentation | Clean dependency installation with zero audit findings; check has zero errors/warnings/hints; production build has 98 pages |

The symbol comparison uses the same minimum-internal compiler extraction as M0,
then selects public records, including inherited/synthesized members on internal
nominals. It establishes a normalized symbol-surface match, not binary ABI or
exhaustive behavioral equivalence. Normal-import consumer tests and the existing
behavior suite supply separate evidence. See [api-comparison.json](api-comparison.json)
and [verification.json](verification.json). Reproduce the comparison after dumping
minimum-internal graphs in the root and core with
`python3 Scripts/compare-migration-api.py`. Graphs from documentation generation
omit synthesized members and are not the right input for that audit.

Core tests now own existing contract, JSON/schema, partial-JSON, SSE, multipart,
DNS-pinning, redirect, response-limit and backpressure checks. Mixed core/provider
regressions remain in the aggregate. Both suites are required in CI. Shared
recording/fixture transports are test-only copies; production has no test support
dependency. CI also runs the isolated consumer and retains the existing artifact
upload policy.

## Limits and handoff

- Core and the aggregate are local development packages. The root's relative
  package dependency is transitional; do not publish a new tag from this state.
  M4/M5 must generate and verify remote distribution manifests first. Existing
  released tags and installation URLs are unchanged.
- Provider extraction and compatible/incompatible provider-version resolution
  are M3 gates. No provider package is independently consumable yet.
- These changes have not been verified on hosted Swift 6.3.3 or an iOS device or
  simulator. The minimum tools/deployment declarations remain Swift 6.3, macOS 12
  and iOS 15; the prior M0 CI result is not evidence for this new source tree.
- No live provider calls, commit, push, organization creation, transfer, tag or
  publication occurred. There are no new upstream version/parity claims.

M3 starts with Anthropic, the generic compatible layer and OpenAI, following the
existing staged plan. Preserve these core/legacy checks while separating provider
settings, factory namespaces and any remaining adapter-specific helper ownership.
