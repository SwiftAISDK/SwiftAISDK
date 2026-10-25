# M0: inventory and package map

Date: 2026-10-25. Status: **complete**. Next stage: M1.

This closes the inventory gate in [the migration plan](../../ModularizationPlan.md).
It records destinations and extraction work against commit
`fc4e5dc5116435d995c71ef36062662b38c42181` (`2.8.1`). No runtime, test, manifest,
example, npm baseline, or supported behavior changed. Module names below are
planning destinations; packages have not been extracted or published.

## Gate evidence

| M0 requirement | Evidence |
| --- | --- |
| Every upstream entry has a disposition | [Package map](package-map.md): 54 entries, their reviewed versions, and destinations. Full preserved behavior/gap notes are in [inventory.json](inventory.json). |
| No unowned source, test, or fixture | 311 runtime Swift files, 365 test files, 12 test-support files, 26 fixtures, and 22 example files each have destinations and SHA-256 fingerprints. The root manifest is fingerprinted separately. All 737 inputs match the baseline commit byte for byte. |
| Every public symbol has a destination | [public-symbols.jsonl](public-symbols.jsonl): 6762 compiler-exported public symbols, including synthesized and inherited members. 704 obtain their source location from their owning type. |
| Provider capabilities and limitations survive | All 54 capability rows and their behavior/gap notes are copied into the inventory, without reclassifying missing ports. Core parity, version ledger, upstream test inventory, capability matrix, and the behavior section of PortingStatus are fingerprinted. |
| Cycles and compatibility risks recorded | [Signature graph](signature-dependencies.json): 164 directed module edges, one remaining strongly connected component under the proposed ownership. The boundary register below also identifies dependencies inside function bodies. |
| Offline suite and consumers recorded | Fresh local Swift 6.4 verification and successful existing Swift 6.3.3 CI for the exact unchanged commit, detailed below. |

The compiler graph is from macOS arm64. Current conditional source sections are
the macOS/Linux-only MCP stdio transport and a FoundationNetworking import. The
snapshot does not claim iOS execution or binary compatibility across module moves.
The manifest still declares Swift tools 6.3, macOS 12, and iOS 15; the recorded
hosted compiler is specifically 6.3.3, not every 6.3 patch release.

## How to use the inventory

- [ownership.json](ownership.json) assigns all 311 source files explicitly. Mixed
  files have line-range overrides. Ranges belong to this exact source snapshot;
  they are not reusable rules for future file revisions.
- [inventory.json](inventory.json) contains file ownership, fingerprints, all 54
  upstream dispositions, and the complete capability notes. Destinations use
  `package-identity/SwiftModule`. Workspace integration tests and test support
  are separate from distributable products.
- [public-symbols.jsonl](public-symbols.jsonl) maps compiler USRs, declarations,
  source locations, and owners. Moving a type into another module changes its
  USR; later comparison must use an explicit migration mapping rather than
  expecting old and new USRs to be identical.
- [signature-dependencies.json](signature-dependencies.json) records resolved
  type/conformance edges for public and internal declarations. It is not a full
  call graph and does not prove that the proposed packages compile independently.

Test destinations use referenced types and provider factories as selection hints.
A test with one concrete package subject is assigned to that package. Mixed,
core, and compatibility tests stay in `workspace/IntegrationTests`; shared test
helpers stay in `workspace/TestSupport`. This keeps every test owned without
prematurely scattering tests across unpublished modules. The 26 OpenAI Responses
fixtures move with their tests. All 19 example targets remain consumer checks in
the workspace. Test imports, fixture bundles, and test-helper dependency closures
must be verified when the owning package is extracted.

M1 should import this snapshot into its structured catalog and derive living
inventories from that catalog. Do not introduce a second manually maintained
release registry or update these M0 baselines during ordinary upstream ports.

## Boundary register

These are required extraction decisions, not behavior changes already delivered.
Line numbers and complete symbol ownership are available in the JSON artifacts.

| Boundary | Current evidence | Required disposition and verification stage |
| --- | --- | --- |
| Shared HTTP configuration | `Models/OpenAICompatibleConfig.swift` mixes public settings, OpenAI/Azure tools, error callbacks, Responses mode, and internal `ModelHTTPConfig`. Generic media and multipart files in utilities accept that config. | M2 extracts a neutral transport kernel; provider-specific options remain with their providers. Do not expose the entire current internal config just to make imports compile. M3 verifies the compatible layer against it. |
| Remaining signature cycle | `SwiftAIProviderUtilities` → `SwiftAIOpenAICompatible` through generic media/file constructors; the compatible layer → utilities through parsing/result helpers. | Resolve the config boundary before treating core extraction as complete. This is the one remaining signature SCC after the planned type splits, not the only possible dependency cycle in method bodies. |
| Generic engine calls concrete providers | `Models/OpenAICompatibleChatCommon.swift` calls `gmiCloudErrorMessage` and `xaiChatWarnings`; compatible chat implementations also dispatch provider-specific behavior. | M3 introduces provider-owned conversion/error hooks or adapters, preserving upstream semantics and tests. M6 applies that boundary to remaining providers. The generic package cannot import every concrete provider. |
| Open Responses shares OpenAI implementation | `AIProviders.openResponses`, `Models/OpenAIResponsesModel.swift`, `Models/OpenAICompatibleConfig.swift`, and Responses helpers implement the generic Responses mode. The nominal `OpenAICompatibleResponsesModel.swift` container has no implementation. | The upstream entry has an explicit `swift-ai-open-responses/SwiftAIOpenResponses` destination even though no whole source file belongs exclusively to it yet. M3 establishes the shared Responses boundary; M6 separates generic mode from OpenAI policy without deleting either behavior. Current shared engine symbols are provisionally owned by the OpenAI/compatible modules. |
| Legacy omnibus factory | `Providers/OpenAICompatibleProvider.swift` dispatches to many providers and exposes concrete return types, including xAI realtime. `Providers/ProviderRegistry.swift` contains all convenience factories. | Keep the existing omnibus type/factories in the compatibility aggregate. Provider modules get their own constructors. An empty shared `AIProviders` namespace can live in contracts; avoid duplicate factory declarations between new modules and the legacy facade. M3 must compile real legacy and modular consumers; typealiases alone are not proof. |
| Default Gateway | `Providers/CustomProvider.swift` starts with `AIDefaultProvider` and its Gateway fallback. | Keep that behavior in the compatibility surface; generic explicit resolution belongs in `SwiftAI`. M2 proves a custom model works without Gateway; M3 proves legacy defaults still work. |
| Contracts mixed with orchestration | `CoreTools.swift`, `CoreTextObjectResults.swift`, `CoreStreamingSpeech.swift`, `ResponseMessages.swift`, and the tool-aware portion of `ResultContent.swift`. | Value/protocol closures stay in `SwiftAIProvider`; executable tools, structured output, high-level speech results, and tool-aware response conversion move to `SwiftAI`. M2 must preserve full returned-type closures without a contracts-to-facade dependency. |
| UI mixed with core | `AIChatTransport.swift` contains `AIChatRequestOptions` used by agents; the tail of `AIAgent.swift` creates UI streams; `Errors.swift` includes UI validation errors. | Neutral agent request options stay in `SwiftAI`; UI stream conversion and UI errors belong to `SwiftAIUI`. M2/M6 keep the core independent of the optional UI module. |
| Public value dependencies | `AIError.gateway` uses Gateway error values; transcription contracts use `DuplexWebSocketCloseMetadata`; decision/evaluation contracts use `AIDecisionBox`. | The map places these pure values in contracts and leaves Gateway parsing and WebSocket transport in their respective implementations. M2 preserves typed public errors and result values; a provider-specific file name must not force a provider dependency into core. |
| Shared files and provider adapters | `Models/FileClients.swift` contains shared multipart logic plus DeepSeek, Google, and xAI clients; `ImageInputCapabilities.swift` adds conformances to many concrete models. Bedrock and Vertex reuse Anthropic/Google behavior. | Split mixed files by recorded ranges, move conformances with their models, and verify adapter dependency closures. Keep legitimate upstream sharing traceable rather than copying implementations into every provider. |
| MCP/tool bridge and module access | `MCPClientActor.swift` exposes `AITool`; current internal helpers are visible across the single runtime target; tests largely use `@testable import`. | MCP may depend on the high-level tool module, while core must not depend on MCP. M2/M3 audit access explicitly: `package` does not cross Swift package boundaries. M3/M6 require external import checks as well as translated tests. |
| Workspace package paths | `.gitignore` currently excludes `/Packages`. | M1 must adjust the rule when introducing canonical package directories and verify that generated development paths cannot leak into distribution manifests. |

Preserve the native transport behavior throughout these splits: DNS-pinned
downloads, original-host TLS, bounded streaming/backpressure, cancellation,
timeouts, realtime/WebSocket close semantics, and MCP OAuth issuer binding.
Their existing assertions remain in the owned test inventory. M2 needs focused
regression tests and the full offline suite, not only a successful new import graph.

## Baseline verification

The [local record](local-baseline.json) includes commands, results, local log
hashes, compiler version, and source equality to the release commit. Full local
logs remain under ignored `.build/migration-m0/`.

| Check | Fresh local Swift 6.4 | Existing hosted Swift 6.3.3 at the same commit |
| --- | --- | --- |
| Capability matrix focus | 4 tests passed | Covered by full suite |
| Full offline suite | 3543 reported tests in 66 suites, 33 explicit live skips, success | 3543 reported tests in 66 suites, 33 explicit live skips, success |
| Consumer examples | All 19 targets build | All example targets build |
| MCP OAuth example | Issuer-bound client secret and stored-binding custom authentication both verified offline | Both offline flows verified |
| Public/internal symbol export | 6762 public symbols mapped; repeated export verifies against the same normalized snapshot | Not exported in that workflow |

Hosted evidence: [workflow run 40151814025](https://github.com/ozio/SwiftAISDK/actions/runs/40151814025),
[test job](https://github.com/ozio/SwiftAISDK/actions/runs/40151814025/job/121044735812),
[build/examples job](https://github.com/ozio/SwiftAISDK/actions/runs/40151814025/job/121046598016).
The checked readback and selected log lines are saved in
[hosted-baseline.json](hosted-baseline.json). Swift 6.3.3 was not rerun locally.
No paid live-provider requests were enabled. Example compilation and offline
OAuth execution do not establish provider-account or published-package acceptance.

## Reproduce the ownership check

At the baseline commit with the recorded Swift 6.4 toolchain:

```sh
swift package dump-symbol-graph --minimum-access-level internal
python3 Scripts/audit-migration-m0.py --check
```

The auditor rejects missing source ownership, unknown modules, invalid overlapping
ranges, missing compiler-symbol locations, unknown fixtures, changed fingerprints,
and stale generated artifacts. Graph hashes normalize source paths and symbol/
relationship array order. `--write` deliberately regenerates the four audit
outputs; use it only when revising the M0 snapshot, after refreshing symbol graphs.
It is not an approval of the changes or a replacement for runtime verification.

Auditor negative controls and final checks are recorded in
[audit-verification.txt](audit-verification.txt). The full Swift suite does not
need another run for these documentation and Python audit changes: the verified
Swift inputs remain byte-identical. No docs-site files changed.

## Handoff to M1

One run covers one stage. M0 is complete; M1 has not started. The next run should
create the structured catalog and repeatable scaffolding/generation checks, using
these package dispositions as input while retaining the existing CLI wrappers.
Runtime extraction belongs to M2/M3. Organization creation and publication remain
M5 work. No commit, push, transfer, or release was made in M0.
