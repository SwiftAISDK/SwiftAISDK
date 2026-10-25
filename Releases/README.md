# Swift package release records

Release records describe Swift versions. npm baselines remain independent in
`Porting/upstream-lock.json`. The current modular pilot is an unreleased candidate;
there are no published modular release-set records in `sets/` yet.

## Reviewed changes

Add one `changes/<id>.json` for a meaningful implementation, public metadata or
minimum-dependency change. `schema.json` validates the shape. Use `draft` while
investigating and `reviewed` after the compatibility rationale and evidence have
been reviewed. A reviewed entry selects extracted release units only; it does not
authorize publication or claim upstream parity. The initial pilot entry relies on
the M2/M3 extraction evidence and retains their recorded limitations.

Each package entry records `initial`, `patch`, `minor` or `major`, consumer-facing
notes and the compatibility assessment. Initial units start at `1.0.0`. Subsequent
changes select the largest requested bump. There are no automatic npm-to-Swift
version translations. `initial` cannot be mixed with a later bump for the same
unit. This planner handles stable candidates; a public prerelease lane must add
explicit prerelease version handling before preview tags are published.

```sh
node Scripts/sdk.mjs release plan --id pilot --output .build/release/pilot-plan.json
node Scripts/sdk.mjs release export --dry-run \
  --plan .build/release/pilot-plan.json --output .build/release/pilot-export
```

The plan lists releases separately from downstream verification. A core patch can
require all providers to be retested while releasing core alone. Increasing a
provider's minimum dependency requires its own release entry. Required compatible
dependency versions must be present in the candidate or recorded release history.
A plan is rejected when its source inputs, Git state or dependency graph changes.

A dirty working-tree plan records `source.commit: null`, its base commit and exact
input hashes. It is useful for a local rehearsal, not publishable provenance.
For publication, commit the reviewed canonical source first and regenerate the
plan. Exported runtime/test bytes match the canonical files; manifests, changelogs,
provenance and standalone CI are generated. The input roots are shared with the
catalog's generated export inventory. Package and root NOTICE files, when present,
are retained with LICENSE.

## Local publication rehearsal

```sh
node Scripts/sdk.mjs release rehearse \
  --export .build/release/pilot-export --staging .build/release/pilot-attempt
node Scripts/verify-release-rehearsal.mjs --report .build/release/rehearsal.json
```

The first command accepts a validated export and creates **local bare Git
repositories only**. It creates annotated SemVer tags, atomically pushes branch
and tag together, then reads back branch/tag/peeled targets and verifies committed
file hashes. It never accepts a GitHub publication destination or writes the
canonical repository's branch or tags.

Repeat the same command and staging path to resume. The attempt journal records
verified packages, but retries re-read real Git refs rather than trusting it.
Dependents stop after a failure. Existing mismatching tags are rejected, never
moved. `--stop-after N` interrupts after a verified package;
`--interrupt-after-push N` exercises the window before the journal is written.
Tests also kill a separate rehearsal process with SIGKILL in that window, then
recover the dead process lock and the already published local tag. Incomplete
local candidate construction can be recreated before publication.

For a later provider-only rehearsal, pass `--baseline <previous-staging>` with
verified local tags. Dependencies are reused, the selected provider commit advances
from its existing history, and old tags remain unchanged. Each attempt owns its
scratch directories; export and staging trees must not overlap.

The second command is the complete M4 gate. It snapshots the current canonical
files into a disposable Git commit, exports twice, verifies deterministic hashes,
exercises interruption/resume, runs all standalone package tests, and builds five
ordinary-import clients using the exported Git tags. SwiftPM mirrors redirect the
public URLs to local bare repositories without editing exported manifests. It then
releases a fixture-only OpenAI metadata patch and builds a mixed client with the
other packages pinned to their previous versions. Reports include exact refs,
consumer lockfiles and commands/log hashes. With `--report`, raw command logs are
retained beside the report. The temporary repositories are deleted afterward.

The snapshot commit and local tag versions are rehearsal evidence, not canonical
commits or public releases. Consumer lockfiles contain local mirror locations and
fixture revisions; do not copy them into applications. The M5 real-consumer check
must produce the published installation/lockfile example.

## Immutable released sets

After real publication and consumer verification, M5 records
`sets/<release-id>.json` with `status: published`, one canonical source commit,
consumed change IDs, package versions, dependency requirements, export hashes,
export commits, annotated tag objects and the consumer-verification digest.
`schema.json` defines that record. Previously committed set files are append-only;
planning rejects modification, deletion, duplicate versions, reused IDs and mixed
source commits. Pending change records remain as history and are consumed by the
set rather than deleted.

Do not create a published record from a dry run. Attempt journals remain in
staging; published sets are finalized only after actual remote readback and clean
consumer checks. M4 provides local mechanics and the record contract. M5 still
owns destination/auth setup, actual publication, hosted compiler checks, upstream
provenance disposition review and documentation continuity.
