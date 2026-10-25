# SwiftAISDK Documentation

This directory contains the maintenance and status documentation for
SwiftAISDK. User-facing guides live in `README.md` and `docs-site`.

## Start Here

| Need | Read |
| --- | --- |
| Use the package | `README.md`, then `docs-site/src/content/docs/getting-started/quickstart.mdx` |
| Understand public docs ownership | `Docs/ProductDocumentation.md` |
| Check current porting status | `Docs/PortingStatus.md` |
| Port upstream code or tests | `Docs/AgentPortingGuide.md` |
| Plan independent Swift packages and upstream synchronization | `Docs/ModularizationPlan.md` |
| Inspect M0 package ownership, extraction boundaries, and baseline evidence | `Docs/Migration/M0/README.md` |
| Maintain the package catalog or scaffold a selected provider | `Porting/README.md`, `Docs/Migration/M1/README.md` |
| Check provider capability coverage | `Docs/ProviderCapabilityMatrix.md` |
| Check npm package baselines | `Docs/ProviderVersionLedger.md` |
| Check core AI SDK parity | `Docs/CoreV6Parity.md` |
| Review the latest package dispositions | `Docs/UpstreamPackageDiffAudit.md` |
| Review the latest upstream test diff | `Docs/FreshUpstreamTestDiffAudit.md` |
| Inspect upstream test inventory | `Docs/UpstreamTestInventory.md` |
| Configure DNS-pinned downloads and custom transports | `Docs/DownloadSecurity.md` |
| Maintain documentation dependencies | `Docs/DocumentationDependencies.md` |
| Review the 2.6.0 follow-up repairs and measurements | `Docs/PostReleaseRepairAudit.md` |

## Document Roles

- `ProductDocumentation.md` is the public-docs contract: what belongs in
  README, docs-site, generated reference, examples, and troubleshooting.
- `PortingStatus.md` is the readable status page for product gaps, package
  baselines, provider coverage, live verification, and reopen rules.
- `AgentPortingGuide.md` is the exact process for future agents. It includes the
  required test-porting and public-documentation steps.
- `ModularizationPlan.md` tracks the migration to independently versioned
  packages in the SwiftAISDK GitHub organization, including upstream mappings,
  generated maintenance metadata, release stages, and acceptance criteria.
- `Migration/M0/README.md` records the completed inventory stage, frozen source
  and API destinations, extraction boundaries, and compiler/test evidence.
- `ProviderCapabilityMatrix.md` and the compiled `AIProviderCapabilities` rows
  are generated from `Porting/packages.json`; registry tests verify real coverage.
- `ProviderVersionLedger.md` renders reviewed entries from
  `Porting/upstream-lock.json`. It is not a task queue.
- `PackageCatalog.md` indexes the planned modular distributions; their state is
  explicit and does not imply publication or independent build readiness.
- `UpstreamPackageDiffAudit.md` records the package-by-package disposition for
  the latest npm drift pass, including portable, already-covered, and explicit
  out-of-scope deltas.
- `UpstreamTestInventory.md` is generated from the Vercel AI SDK monorepo and is
  intentionally large.
- `FreshUpstreamTestDiffAudit.md` classifies the latest upstream executable and
  declaration-test diffs separately.

Historical provider-by-provider narratives and one-off checklist files have
been folded into the status and agent guide. The durable evidence should live in
tests, generated inventories, and the version/capability ledgers.

- [M2 core extraction](Migration/M2/README.md): standalone runtime modules, compatibility and verification evidence.

- [M3 provider pilot](Migration/M3/README.md): Anthropic, compatible and OpenAI packages, independent version constraints and preserved legacy clients.

- [M4 publication rehearsal](Migration/M4/README.md): deterministic exports, standalone Git consumers, independent patches and recovery after interrupted publication.
- [Release record workflow](../Releases/README.md): reviewed changes, candidate plans, attempt journals and immutable published-set schema.
