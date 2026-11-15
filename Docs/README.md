# SwiftAISDK Documentation

This directory contains the maintenance, status and audit records for
SwiftAISDK. User-facing guides live in the [README](../README.md) and the
[docs site](../docs-site/src/content/docs); [Migration](Migration.md) and
[DownloadSecurity](DownloadSecurity.md) are user-facing references kept here.

## Start Here

| Need | Read |
| --- | --- |
| Use the package | [README](../README.md), then the [quickstart](../docs-site/src/content/docs/getting-started/quickstart.mdx) |
| Contribute code, tests, or documentation | [CONTRIBUTING.md](../CONTRIBUTING.md) and [AGENTS.md](../AGENTS.md) |
| Port upstream code or tests | [AgentPortingGuide.md](AgentPortingGuide.md) |
| Run the complete weekly upstream update | [WeeklyUpstreamUpdate.md](WeeklyUpstreamUpdate.md) |
| Edit public docs, or find which docs-site pages are generated | [ProductDocumentation.md](ProductDocumentation.md) |
| Check current porting status and known gaps | [PortingStatus.md](PortingStatus.md) |
| Migrate from 2.x to modular packages | [Migration.md](Migration.md) |
| Find a package, its modules and dependencies | [PackageCatalog.md](PackageCatalog.md) |
| Maintain the package catalog or scaffold a selected provider | [Porting/README.md](../Porting/README.md) |
| Check provider capability coverage | [ProviderCapabilityMatrix.md](ProviderCapabilityMatrix.md) |
| Check npm package baselines | [ProviderVersionLedger.md](ProviderVersionLedger.md) |
| Check core AI SDK (V7) parity | [CoreV6Parity.md](CoreV6Parity.md) |
| Inspect upstream test inventory | [UpstreamTestInventory.md](UpstreamTestInventory.md) |
| Configure DNS-pinned downloads and custom transports | [DownloadSecurity.md](DownloadSecurity.md) |
| Maintain documentation dependencies | [DocumentationDependencies.md](DocumentationDependencies.md) |
| Set up or verify the M3 release runner | [M3Runner.md](M3Runner.md) |
| Prepare, export and publish releases | [Releases/README.md](../Releases/README.md) |

## Archive

Dated pass records (weekly audits, release and consumer verification,
superseded diff audits and status history) live in [Archive](Archive/README.md).
They are evidence for past passes, are excluded from default search by `.ignore`,
and should be read only when investigating an earlier pass. The current pass is
summarized in [PortingStatus.md](PortingStatus.md).

## Document Roles

- `ProductDocumentation.md` is the public-docs contract: what belongs in
  README, docs-site, generated reference, examples, and troubleshooting, and
  which docs-site files are generated.
- `PortingStatus.md` is the readable status page for product gaps, package
  baselines, provider coverage, live verification, and reopen rules.
- `AgentPortingGuide.md` is the exact process for future agents. It includes the
  required test-porting and public-documentation steps.
- `WeeklyUpstreamUpdate.md` consolidates the scheduled maintainer workflow from
  fresh registry discovery through verified modular publication and reporting.
- `Migration.md` explains the 3.0 compatibility boundary and package selection.
  It is also published as the docs-site "Migrate to 3.0" page.
- `ProviderCapabilityMatrix.md`, `PackageCatalog.md` and the compiled
  `AIProviderCapabilities` rows are generated from `Porting/packages.json`;
  registry tests verify real coverage.
- `ProviderVersionLedger.md` renders reviewed entries from
  `Porting/upstream-lock.json`. It is not a task queue.
- `UpstreamTestInventory.md` is generated from the Vercel AI SDK monorepo and is
  intentionally large.

The durable evidence lives in tests, generated inventories, the
version/capability ledgers and the dated records in the archive.
