# M7 — modular umbrella and migration

Status: package publication and local/public verification complete; final CI
restoration, automation readback and hosted deployment remain pending.
Previous stage: [M6](../M6/README.md).

The production distribution source is
`7fc9b4cd72f8f83b75ba7eee2e38d37127539317`. The 3.0 umbrella release adds the
verified release records and installation documentation to that source. This
stage changes packaging and maintenance tooling; it does not select new upstream
providers, advance production npm baselines, or change provider behavior.

## Published packages and compatibility

All 52 packages are independently installable from public GitHub tags. M7
publishes 48 initial `1.0.0` releases plus core and Anthropic `1.1.0`; OpenAI and
OpenAI-compatible remain at `1.0.0`. Their existing tags were not rewritten.

- [Immutable M7 release set](../../../Releases/sets/modular-3.json) records the
  50 new releases, source commit, export digests, dependency ranges and tag objects.
- [Publication readback](publication.json) records the GitHub Releases and fresh
  remote payload verification from the resumable publisher.
- [Complete tested dependency selection](../../../Releases/umbrella/3.0.0.json)
  combines the pilot and M7 releases. It describes a verified combination;
  consumers still resolve the compatible ranges in `Package.swift`.
- [Public mixed-client lockfile](MixedProviders.Package.resolved) pins core 1.1.0,
  Anthropic 1.1.0 and OpenAI/compatible 1.0.0.
- [Migration guide](../3.0.md) covers native imports, existing `settings:` factories,
  common nominal types, source/ABI boundaries, optional MCP/UI, and the 2.x line.

The public root manifest uses remote dependencies only. A generated ignored
workspace (`sdk.mjs dev`) links the canonical sources/tests and derives local
package paths from the same catalog. Ordinary and module-qualified legacy names
continue through `import SwiftAISDK`. Native core has no concrete provider or
implicit default Gateway.

## Verification evidence

- [Local committed-source gate](local-verification.json): all 11 required checks
  passed on Swift 6.4. The full 3549-test suite retained 33 explicit live skips;
  iOS 15 simulator-target compilation, existing examples and offline MCP OAuth
  also passed. Documentation installed cleanly, reported no diagnostics and built
  99 pages. No device runtime or paid-provider-call validation is claimed.
- [Distribution verification](distribution-verification.json): 52 deterministic
  exports, 1828 standalone tests and 106 ordinary-import clients, including
  minimum/latest compatible dependencies, a mixed published/candidate graph and
  the complete compatibility facade. Synthetic tags are explicitly fixture data.
- [Actual public consumers](public-consumers.json): 59 clean clients use real Git
  URLs without mirrors, local dependencies or credentials. Five usage examples
  exercise offline behavior; 52 import clients verify every distribution; two
  mixed clients change only Anthropic from 1.0.0 to 1.1.0 while the core, OpenAI
  and compatible revisions stay pinned. Import checks alone do not claim every
  provider was contacted.
- [Public complete candidate](complete-candidate.json): the canonical source
  revision and all 52 published dependencies compile and run through ordinary
  `import SwiftAISDK`, qualified legacy names, explicit/default model resolution
  and two injected offline transport calls. All 53 resolved revisions are checked.
- [Legacy public consumer](legacy-public.json): 2.8.1 compiles and runs the same
  ordinary-import example at its original release commit.
- [Preservation](preservation.json): all 1039 pre-existing runtime/test/resource
  files are unchanged from M6, as are the reviewed npm baselines, capability
  matrix, upstream test inventory and immutable pilot release record.

The first public import pass exposed a verifier setup error: naming the client
folder after its dependency creates a SwiftPM root-identity collision. Prefixing
client directories fixes the harness. All public consumers were then verified
with the corrected script; no published package or tag was changed.

## Maintenance after migration

[Maintenance rehearsal](maintenance-rehearsal.json) replays the real OpenAI
`4.0.101 → 4.0.102` update using integrity-checked archives and immutable,
release-matched upstream tests. Controlled regressions fail the translated tests;
repairing the provider leaves the shared parser test failing, then repairing that
helper passes both. Only core/OpenAI receive synthetic patch releases; unchanged
provider tags stay fixed. Production behavior was already ported before M7.

The shared change selects all downstream packages. Mapping is deliberately
conservative: coarse or unknown ownership widens verification rather than omitting
possible dependents. A one-command disposable provider registration generates its
manifest, mapping, CI selection, export, documentation index and workspace entry.
Both an unimplemented scaffold and an extracted-but-unreviewed scaffold are
rejected by the release planner. Additional hard-coded package lists: **zero**.

The new upstream preparation command does not advance reviewed baselines. A missing
matching test ref is recorded as a gap. Review behavior and tests, then update the
structured provenance and Swift change entry. See the [porting guide](../../AgentPortingGuide.md)
and [release workflow](../../../Releases/README.md).

## Final handoff

[Repository provisioning](repository-provisioning.json) records that Actions was
disabled before the first push in each of the 48 new destinations. [Tag rules](tag-protection.json)
protect their published tags from updates/deletion, matching the pilot policy.
The user's [temporary CI policy](../M6/ci-budget-policy.json) applies through the
main publication work. Final restoration and hosted evidence will be appended
here after the umbrella release is verified.

The known pre-existing 1 ms timeout-test flake is retained in M6 evidence. No test
assertion, live-test guard, capability, upstream gap or prior release was weakened
to complete this migration.
