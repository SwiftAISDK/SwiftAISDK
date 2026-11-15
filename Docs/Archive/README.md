# Archive

Service records of past maintenance passes. Nothing here describes how to use
SwiftAISDK or the current state of the port; read it only when you are
investigating what an earlier pass decided, verified or published.

## Archive policy

- **What goes here.** Every dated record: weekly upstream audits (`.md` and
  `.json`), release, consumer and runner verification reports, upstream
  integrity snapshots, superseded diff audits, post-release repair notes, and
  narrative history removed from living documents. File names keep their date
  (`<Kind><YYYYMMDD>.<ext>`), so the newest record sorts last.
- **What stays out.** Current state belongs in the living documents:
  `Docs/PortingStatus.md` (state, gaps, checklist), the generated ledgers and
  matrices, `Porting/*.json`, and the docs site. When a living document grows
  dated "the YYYY-MM-DD pass…" paragraphs, move them here in the same change
  and keep only the current behavior in the living text.
- **Write once.** A record is not edited after its pass ends, except to fix a
  broken link. A later pass writes a new record instead.
- **Links.** Living documents link only to the newest relevant record. Paths in
  immutable release records (`Releases/umbrella`, `Releases/sets`,
  `Releases/changes`) and in exported `Packages/*/Porting/*.json` provenance
  refer to the location at their recorded commit; the same file name now lives
  in this directory.
- **Not loaded by default.** This directory is excluded from ripgrep-based
  search by the repository `.ignore` file and is not published on the docs
  site, so routine agent searches and users do not see it. Read or search it
  explicitly when needed, for example `rg --no-ignore-dot <pattern> Docs/Archive`.

## Contents

| Record | Files |
| --- | --- |
| Status history | `PortingStatusHistory.md` |
| Core parity deltas and package diff notes | `CoreParityHistory.md` |
| Weekly upstream audits | `WeeklyUpstreamAudit<date>.md` and `.json` |
| Release and consumer verification | `ReleaseVerification<date>.json`, `PublicConsumerVerification<date>.json` (`PublicConsumerVerification<ReleaseName><date>.json` for an extra release on the same day), `UmbrellaConsumerVerification<date>.json`, `WeeklyUpstreamVerification<date>.json`, `M3RunnerVerification<date>.json` |
| Upstream archive integrity (2026-10-25) | `UpstreamPackageIntegrity.json` |
| Package disposition snapshot (2026-10-25) | `UpstreamPackageDiffAudit.md` |
| Upstream test diff snapshot (2026-11-01) | `FreshUpstreamTestDiffAudit.md` |
| Post-release repairs after 2.6.0 and 2.8.0 | `PostReleaseRepairAudit.md` |
| Provider porting notes history | `ProviderNotesHistory.md` |
| Package READMEs before the 2026-11-15 rewrite | `PackageReadmeHistory.md` |
| Release set narratives | `ReleaseSetHistory.md` |
