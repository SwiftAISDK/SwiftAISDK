# M1: catalog and repeatable tooling

Date: 2026-10-25. Status: **complete**. Next stage: M2.

This stage implements the catalog and scaffolding gate in
[ModularizationPlan.md](../../ModularizationPlan.md). It follows the completed M0
inventory and leaves runtime extraction to M2.

## Delivered structure

- [Porting/packages.json](../../../Porting/packages.json): 52 planned Swift
  release units, module/product identities, proposed dependency ranges, guides,
  and the existing 54 provider capability rows with all notes.
- [Porting/upstream-lock.json](../../../Porting/upstream-lock.json): all 54
  reviewed upstream entries and their unchanged versions/evidence, imported
  archive identities, pinned inventory test refs, and explicit provenance gaps.
- `Packages/<identity>/Porting/map.json`: coarse upstream/Swift source and test
  mappings for every package. Workspace-only ownership remains explicit.
- Generated canonical manifests, [package index](../../PackageCatalog.md),
  Swift capability data, version/capability tables, CI matrix, export file plans,
  and local/remote workspace identity data.
- [Scripts/sdk.mjs](../../../Scripts/sdk.mjs): validation, generation, package
  registration, upstream CLI delegation, and conservative affected-check selection.
  The existing version/test-inventory CLI commands and public-doc generator now
  consume the same structured inputs.

Operational commands and limits are documented in
[Porting/README.md](../../../Porting/README.md).

## Exit gates

| Gate | Proof |
| --- | --- |
| Existing baselines and coverage preserved | Migration import test compares all versions, ledger kinds/evidence, ordered capability rows, factories, supported capabilities, file/skill flags, and full notes with the frozen [import-baseline.json](import-baseline.json). |
| Generator rerun makes no diff | `generate --check` and a second generation report no changed files; test checks all registered generated artifacts. |
| One registration adds a package | Tooling test invokes the real CLI against a disposable checkout and verifies its map, source/test/guide scaffold, manifest, index, CI entry, export plan, and workspace identity. No hard-coded provider list is edited. |
| Scaffold does not imply support | The fixture has no reviewed version or capabilities, no independent CI build readiness, and no export readiness; injecting a capability row is rejected. |
| Existing CLIs remain usable | Version wrapper tested with a mock npm executable, including lookup failure; inventory wrapper tested with a local upstream Git fixture. These are offline compatibility checks, not a fresh npm parity audit. |
| Invalid metadata fails | Tests cover unknown schema fields, duplicate IDs, unknown module dependencies, cycles, unsafe directory identity, missing mapped files, unowned inputs, and stale generated output. |
| Swift consumer behavior retained | Focused capability tests plus the full offline Swift suite. Only the generated descriptor's ownership instructions and the catalog-driven inventory assertion changed; provider implementation files remain untouched. |
| Public documentation verified | Clean npm install, documentation check, and site build; provider page generation reads the catalog directly. |

Final command outcomes and log fingerprints are recorded in
[verification.json](verification.json). Eight tooling tests pass, including the
optional frozen-import comparison. Swift 6.4 passes all 3543 reported tests in
66 suites, with 33 explicit live skips. The capability focus passes four tests.
All 52 manifests parse with SwiftPM and retain catalog product names, dependency
identities, and minimum versions. Documentation checks report zero errors or
warnings; the production-configured build produces 98 pages.

## Deliberate remaining work

All package manifests are `planned` and dependency ranges are proposed. Parsing
them proves their Swift manifest syntax, not independent compilation. The root
package and current consumers still use the existing aggregate. M2 must resolve
the core boundaries identified in M0 and then update actual module dependencies.

Imported maps intentionally do not claim individual test dispositions or a full
call graph. Affected selection widens coarse/unknown mappings to the complete
package set. Granular extraction maps, release-matched tests, and contract-family
review remain explicit gates before independently shipping those packages.

Archive integrity is missing in the old evidence for LMNT and Vercel; all imported
test refs are inventory snapshots, not verified matching release refs. These
unknowns are retained as metadata, without changing reviewed npm versions or
claiming new parity. Full immutable diff preparation and executable release
export remain later migration work.

The workflow now checks generated metadata and tooling tests; it retains the
existing artifact-upload restriction. No organization, remote repository,
commit, tag, push, or release was created in M1.
