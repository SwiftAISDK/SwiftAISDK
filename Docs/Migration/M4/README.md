# M4: publication rehearsal

Date: 2026-10-25. Status: **complete**. Next stage: M5.

The [migration plan](../../ModularizationPlan.md) now has executable release
planning, deterministic standalone export and a resumable local publication
rehearsal. M4 does not create an organization, transfer a repository or publish
public versions. All Swift runtime and test files, and the frozen M0–M3 evidence,
remain unchanged from the start of this stage.

## Delivered workflow

| Surface | Responsibility |
| --- | --- |
| `Releases/changes/*.json` | Reviewed Swift bumps, consumer notes and compatibility rationale; npm baselines remain separate |
| `Releases/schema.json` | Change and immutable published-set record contracts |
| `release plan` | Initial 1.0.0 or subsequent SemVer bump; dependency availability; separate release and downstream verification selections |
| `release export --dry-run` | Allowlisted standalone package trees, remote dependency ranges, provenance, changelogs, license/notices, mappings and CI |
| `release rehearse` | Local bare repositories, annotated tags, atomic branch/tag pushes, ref readback, payload verification and restart journal |
| `verify-release-rehearsal.mjs` | Full exported-package and clean-client acceptance gate, including an independent provider patch |
| `.github/workflows/package-check.yml` | One maintained standalone CI recipe, copied unchanged into exports and called by a minimal workflow |

Full commands and record semantics are in [Releases/README.md](../../../Releases/README.md).
The canonical `Releases/sets/` directory has no published record yet. Rehearsal
results live in staging or the migration evidence, never as invented public releases.

### Planning and independent versions

Reviewed entries select extracted packages only. Multiple entries use the largest
requested bump. Initial and subsequent-release bumps cannot be mixed. Missing
compatible dependencies, undeclared requirement changes, malformed records,
reused release IDs, duplicate published versions and mixed canonical commits fail
validation. Previously committed published-set files cannot be edited or deleted.

Core changes select dependent packages for verification without forcing those
packages to release. A provider that raises its minimum dependency must have its
own change entry. The current planner computes stable versions; a public prerelease
lane must explicitly implement prerelease versions before any preview publication.

A dirty canonical checkout produces `source.commit: null`, its base commit and
exact input hashes. It is clearly a candidate, not committed release provenance.
Planning/export is rejected when those inputs or Git state changes. Publication
must regenerate the candidate from the reviewed canonical commit in M5.

### Export boundary and retained port identity

The catalog generator and exporter share input-root selection. Expansion records
an explicit path/hash allowlist. Swift sources, tests and fixtures are copied
byte-for-byte; no implementation is rewritten to make an export compile.
Package manifests are rendered with the same package identities and compatible
Git version ranges. Canonical local paths and verification mirror configurations
are absent from exported manifests and Git trees.

Exports include package/root attribution notices when present, LICENSE, a rendered
README with the authored usage guide, a changelog, PROVENANCE.json, the package's
upstream lock subset and capability rows. The original canonical port map is
retained verbatim. A standalone map uses package-relative paths and lists the
canonical-only integration references separately. This preserves traceability
without silently copying the aggregate or sibling source files into a package.

Existing `inventory-snapshot-not-release-verified`, contract-review gaps and coarse
mapping dispositions are preserved. Packaging success does not create new upstream
parity evidence. No upstream version or capability row was advanced.

The development implementation uses generated local canonical manifests and
remote distribution manifests from one catalog, replacing the originally proposed
separate override workspace. For verification, SwiftPM URL mirrors redirect the
unchanged remote manifests to disposable local bare repositories. Consumer
resolution verifies exact package identities, versions and commit revisions.

### Resumable publication mechanics

The rehearsal accepts local staging directories, not a network publication URL.
For each package it constructs an exported release commit and annotated SemVer
tag, atomically pushes main and the tag to a local bare repository, then reads back
main, the tag object and its peeled commit. It also verifies every committed file
against the export hash list. Dependents wait for successful dependency readback.

The attempt journal is written after verification. A retry re-reads refs and
payloads, recovers a completed push whose journal update was interrupted, and
rejects conflicting refs instead of replacing tags. Local candidate construction
and bare-repository initialization use recoverable staging. A process lock prevents
concurrent attempts; a verified dead owner can be recovered. Export/staging trees
must not overlap.

A baseline attempt can seed a later provider-only release. The selected provider
advances from its existing Git history; its old tag and all unchanged dependency
tags/heads remain intact. These local mechanics are preparation for the real
multi-repository publisher; they do not exercise GitHub credentials, rate limits,
repository settings or the GitHub Releases API.

## Verification

See [verification.json](verification.json) and the full
[rehearsal record](release-set.rehearsal.json) for final commands, hashes, source
snapshot IDs, exported refs and consumer lockfiles.

The acceptance pipeline creates a disposable committed snapshot of current
canonical files. It exports that one snapshot twice and compares complete
manifests and file hashes. The snapshot commit is recorded separately from the
real canonical base commit; no canonical branch or tag is changed.

| Gate | Evidence |
| --- | --- |
| Deterministic export | Two exports of one committed snapshot have identical bytes and hashes for all four packages |
| Standalone package tests | Core 126, Anthropic 135, compatible 7 and OpenAI 270: 538 tests from exported Git clones |
| Ordinary external consumers | CoreOnly, AnthropicOnly, OpenAICompatibleOnly, OpenAIOnly and MixedProviders build/run with exact exported tag revisions |
| Independent patch | Fixture-only OpenAI 1.0.1 exports/releases alone; mixed client retains core, Anthropic and compatible 1.0.0 |
| Recovery | Interruption after atomic push before journal update; retry keeps the same annotated tag; repeated completed attempt is unchanged |
| Abrupt process death | Tool test sends SIGKILL to a separate rehearsal process after push; dead lock and missing journal receipt recover without replacing the tag |
| Conflicting remote tag | Retry fails and leaves the conflicting tag intact; dependent publication does not start |
| Historical records | Modification/deletion of committed sets and reuse of their IDs are rejected |
| Tooling | 17 tests pass with no skips; deterministic generation passes for 52 packages / 54 upstream entries |
| Preservation | 825 existing runtime/test/frozen-evidence files retain their pre-M4 hashes |

The standalone CI recipe is checked through the same package build/test behavior
locally; it has not run on hosted Actions for this uncommitted change. The canonical
workflow now invokes the release rehearsal. Neither the standalone recipe nor
rehearsal uploads artifacts. Existing documentation-only uploads on main retain
their one-day policy.

The original 3007 aggregate tests were not relocated or changed in M4. M3's full
3545-test/API/iOS receipts remain frozen; M4 supplies fresh evidence specifically
for exported packages, tooling and clients. Paid provider requests are not used.

## M5 handoff and remaining gates

- Keep existing tagged 2.x installation working. The current canonical root still
  uses local development dependencies and must not be tagged as a public release.
- Commit the reviewed migration source before producing publishable provenance;
  dirty-preview hashes and disposable snapshot commits are not substitutes.
- Confirm the GitHub organization name, configure scoped credentials/destinations,
  transfer the canonical repository if appropriate, and verify documentation
  continuity before changing public installation guidance.
- Review retained upstream evidence gaps and the new public adapter API contract.
  Obtain fresh hosted minimum Swift 6.3.3 verification; local M4 execution uses
  Swift 6.4 on macOS arm64. No new device/simulator runtime proof is claimed.
- Actual remote publication must reuse the ordering/immutability/readback rules,
  then verify clean clients against real public tags and finalize the immutable
  published release-set record. The rehearsal lockfiles contain local mirror
  locations and fixture commits; they are evidence, not application lockfiles.
- No canonical commit, push, tag, organization creation, repository transfer,
  public package release or live provider call occurs in M4.
