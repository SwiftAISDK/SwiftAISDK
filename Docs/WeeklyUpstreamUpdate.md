# Weekly Upstream Update

This is the maintained instruction set for the SwiftAISDK weekly upstream check.
It consolidates the scheduled task's discovery, porting, verification, publication,
and reporting requirements. The automation should point here and to [AGENTS.md](../AGENTS.md)
instead of maintaining a conflicting copy. Read the current versions on every run.

Use the [contributor guide](../CONTRIBUTING.md) for setup, the
[agent porting guide](AgentPortingGuide.md) for translation and ownership, and the
[release workflow](../Releases/README.md) for authoritative publication commands.

## Working contract

- Work in the current workspace and on the current branch. Do not create a branch
  or PR without an explicit request. Preserve other tasks' committed, staged, and
  unstaged work; stage only the reviewed files or hunks belonging to this run.
- The scheduled maintenance task authorizes the conditional commits and releases
  below. It does not authorize unrelated changes, history rewrites, force pushes,
  moving published tags, or editing generated distribution implementations.
- Check configured human Git author and committer identities before committing.
  In the maintainer's checkout use `Nikolay Solovyov <i@mr-ozio.ru>`.
  Never attribute commits to an agent or add AI coauthor/signoff trailers,
  generated-by footers, or session links. A PR description carries only the single
  AI-assistance block defined in AGENTS.md "Pull Request Descriptions". Preserve
  genuine human and legal attribution.
- Write observable acceptance gates before substantial work. Record exact source
  revisions, commands, exits, results, and unresolved evidence; do not silently
  lower the acceptance bar to finish a run.
- Keep existing unrelated edits out of automation commits and exports. If their
  overlap prevents safe work or publication, report the concrete conflict.

## 1. Establish the source and release baseline

Start with:

```sh
git status --short --branch
git fetch --prune --tags origin
git log --oneline origin/main..HEAD
```

Inspect `Porting/packages.json`, `Porting/upstream-lock.json`, `Releases/sets/`,
the owning `Packages/*` sources/tests/maps, compatibility tests, porting status,
version ledger, capability matrix, and upstream test inventory. Record the base
commit and pre-existing dirty paths so preservation can be checked at the end.

Read the current [AGENTS.md](../AGENTS.md), [porting guide](AgentPortingGuide.md),
[catalog guide](../Porting/README.md), and [release workflow](../Releases/README.md).
Reconcile newer user instructions, previous incomplete runs, journals, and source
changes before resuming. Do not restart an existing operation merely because it
is still running.

## 2. Discover current upstream packages and versions

Check `ai` and every `@ai-sdk/*` package already ported or explicitly mentioned
in this repository. Use fresh npm metadata, not a remembered version list:

```sh
node Scripts/check-upstream-versions.js --all
node Scripts/check-upstream-versions.js --discover-packages --discover-kind provider,adapter,core
```

Use `npm view`, `npm search --json`, registry metadata, and published tarball
metadata as needed. Query both registry/search metadata and the exact registry
prefix list for `@ai-sdk/`; local dependencies and search alone can miss a new
provider. Record discovery errors explicitly rather than interpreting them as
no updates.

For every tracked or newly discovered package, record its local/reference
version, latest published version, disposition, and supporting evidence.
Evaluate a changed package independently even when it shares helpers with others.
Seed packages without implementation have no portable behavior; say so explicitly.

## 3. Prepare release-matched evidence

For each differing package, use a new work directory:

```sh
node Scripts/sdk.mjs upstream prepare --package @ai-sdk/openai --work-dir /tmp/swiftai-openai-review-new
```

Choose a genuinely new directory for each preparation. Inspect `work-item.json`,
the summary, source/declaration diffs, changed tests, exact test refs, and mapped
Swift owners/downstream checks. Verify published archive integrity and matching
release versions. Existing preparations are immutable; retry in a new directory
after ownership or evidence changes.

Preparation does not advance a reviewed npm baseline. An inventory/fallback test
snapshot is not matching-release evidence. Missing release evidence stays an open
gate; never substitute a more convenient upstream checkout and call it parity.

## 4. Port behavior, then tests, then documentation and metadata

Read the matching-release upstream tests before implementation. Compare public
exports, API/types, request builders, response parsers, provider options,
headers/user-agent, error handling, stream behavior, telemetry metadata, and
fixture patterns with the owning Swift code.

Preserve the local package architecture and Swift-native behavior. Follow the
porting guide for typed settings, structured JSON, lifecycle events, cancellation,
retries, errors, and public API compatibility.

For all packages, including existing core/provider/UI surfaces:

- Translate every upstream test covering the exposed Swift surface. Keep its
  scenarios, fixtures, expected results, assertions, errors, and stream lifecycle.
- Map each source test file to Swift tests and a documented disposition. Justify
  JS/browser/Node-only exclusions separately. Local Swift/platform tests supplement
  the translated tests; they do not replace matching-release acceptance evidence.
- Do not weaken assertions or replace upstream cases with tests that only repeat
  the current Swift implementation. Required failing tests remain open gates.

Implement newly discovered full provider packages and provider components in the
same pass without another confirmation: runtime, public API, translated tests,
catalog/capabilities, public docs, and release metadata. Discovery, a scaffold,
or a suggestion to implement later is not a completed port. Platform-only
exclusions or unavailable evidence must be stated precisely, not hidden as success.

Update structured provenance, reviewed baselines, package ownership maps, and
test dispositions only after review and implementation. Then regenerate:

```sh
node Scripts/sdk.mjs generate
```

Update the owning docs-site guides/examples and the status, version, capability,
and parity documents. README changes are needed only for onboarding, installation,
package selection, or navigation; keep it within 150 lines. Record a reviewed
`Releases/changes/` entry for genuinely changed Swift release units.

## 5. Pass the required verification gates

Run focused owning-package tests first and compatibility tests against local
sources. Then run every package suite and the complete compatibility suite:

```sh
swift test --package-path Packages/swift-ai-openai --filter openAI --no-parallel
node Scripts/sdk.mjs dev test --filter yourFocusedTest --no-parallel
node Scripts/test-packages.mjs
node Scripts/sdk.mjs generate --check
node --test Scripts/tests/*.test.cjs
node Scripts/verify-core-isolation.mjs
node Scripts/verify-provider-isolation.mjs
node Scripts/verify-provider-versions.mjs
```

Root `swift test` resolves published dependencies and does not substitute for
current-source package tests. Check the changed dependency closure, deterministic
exports, exported package tests, and minimum compatible dependency ranges using
the catalog/release verification tools. Verification selection is not execution.
Shared-helper changes widen downstream verification without forcing releases of
unchanged dependents.

When docs-site changes, run:

```sh
npm ci --prefix docs-site
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://swiftaisdk.github.io npm --prefix docs-site run check
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://swiftaisdk.github.io npm --prefix docs-site run build
```

Before committing, run `git diff --check`, inspect the staged patch, and verify the
resulting `git show`. Optional paid/live checks remain behind `LIVE_AI_TESTS=1`;
report whether they actually ran. Preserve logs and actual exit/completion records
for long operations. A disappeared process, started job, or cancelled workflow
does not establish success.

## 6. Choose the correct completion path

| Outcome | Action |
| --- | --- |
| No changes needed | Report checked versions and provider discovery. Do not create an empty commit, tag, or GitHub Release. |
| Local required checks or evidence fail | Do not commit, tag, or push the incomplete port. Preserve work and report the failing gate and remaining work. |
| Local changes are verified | Stage only this task, commit coherently on the current branch, and enter the conditional release process. |
| Hosted/publication gate fails after the source commit | Keep completed history and immutable releases intact; stop the next publication step, retain the journal, and report exact partial state. |

Follow the commit rules in [AGENTS.md](../AGENTS.md#commit-messages), for example
`feat(upstream): Add provider capabilities and preserve stream metadata`.
Use a more specific scope/summary when possible. Keep a coherent sync together
and split unrelated work; never use a generic `Update AI SDK upstream port` subject.
Record baseline deltas, compatibility limits, and actual checks in the body and
linked audit. Do not add AI attribution.

## 7. Publish only changed release units

1. Use the canonical repository only. Swift SemVer and npm baseline versions are
   independent. Choose initial/patch/minor/major from Swift API and behavioral
   compatibility; do not bump unchanged providers or dependencies.
2. Fetch branch and tags again immediately before release. Confirm a normal
   fast-forward push is possible and that no unrelated/unverified ahead commits
   would be published. Commit verified canonical source, push without force, and
   require successful canonical hosted CI on that exact source SHA. Do not create
   an intermediate root tag or a root tag for a provider-only release.
3. If CI was intentionally suspended, restore it only under the user-agreed
   condition. Do not bypass it with a fabricated receipt or a docs-only green run.
   The canonical workflow currently prefers M3 for trusted `main` SDK checks and
   dispatches one GitHub-hosted replacement after a 90-second queued grace period.
   See [M3Runner.md](M3Runner.md). Verify the actual executed `test` job and exact
   SHA; runner probes and cancellation of the original run do not prove SDK success.
4. Create a release plan, deterministic exports, applicable local rehearsal, and
   dependency checks using [Releases/README.md](../Releases/README.md). Regenerate
   the plan whenever its inputs change; a dirty-tree export is a preview, not
   publishable provenance. Expensive publication-tooling rehearsals apply when
   changing that tooling rather than to every ordinary push.
5. After successful exact-source CI, use `release export --publication` and
   `release publish --ci-run` with a durable staging directory. The publisher
   commits exports, creates annotated tags, and atomically pushes each changed
   unit's branch/tag in dependency order. Do not edit distribution implementations,
   move published tags, or add per-provider publication workflows/manual lists.
6. If a new destination is required, create it according to the catalog identity
   and existing organization/access rules before publishing. Do not let a missing
   destination turn a complete provider port into a permanently deferred scaffold.
7. Write release notes in English: actual user-visible behavior, upstream parity
   scope, compatibility/migration, commands/results, and known gaps. Use source,
   diffs, structured ledgers, and test evidence; a reviewed baseline alone is not
   full parity. Save exact notes to a file and pass `--notes-file`. Exclude secrets,
   temporary paths, internal automation narratives, and unverified claims.
8. Read back real remote branch SHAs, annotated and peeled tags, GitHub Release
   targets, provenance, and export hashes. Check standalone hosted CI and clean
   consumers of actual public tags without mirrors or local overrides; include
   version-specific minimum compatible graphs. A local rehearsal proves neither
   public availability nor published-consumer success.
9. Only after publication and consumer verification, add the append-only released
   set and evidence. Write the pass's audit and verification records to
   `Docs/Archive/` under the [archive policy](Archive/README.md), and point
   `Docs/PortingStatus.md` at the new records instead of appending dated narrative
   to living documents. Preserve historical records and old source/test references.
   For partial failure, reconcile immutable refs and resume the same journal;
   do not start a conflicting release or silently repeat ambiguous mutations.

## 8. Release the umbrella only when warranted

The compatibility umbrella is separate. Release it when compatibility API,
minimum dependencies, or the user installation contract changes. Provider-only
changes do not automatically require an umbrella release.

All dependency tags must already exist and pass their checks. Keep the root
manifest remote-only; local development continues through `sdk.mjs dev`.
Choose the next appropriate semantic version, create an annotated tag on the
final verified commit, and atomically push the current branch with that tag.
Create the GitHub Release using `--verify-tag` and the exact target SHA.

Never rewrite existing 2.x or other published tags. Do not change docs-site's npm
package version, MCP identity, or upstream version literals merely to bump the
Swift umbrella version.

## 9. Verify docs and report the actual result

After public docs change, wait for the completed hosted deployment and inspect
the real published page. A queued, running, cancelled, or superseded workflow is
not a successful deployment. Preserve unrelated browser tabs and verification
artifacts according to the user's browser rules.

The final report must include:

- Every differing upstream package's old/latest version, disposition, implemented
  behavior, tests, and remaining gaps, or a full package-by-package audit link with
  a concise summary.
- New implemented providers, upstream versions, translated test evidence, and
  actual published Swift units. List seed packages without implementation separately.
- Changed Swift packages, old/new versions, SemVer reasoning, canonical SHA,
  verified export/tag/Release refs, and test/consumer results.
- The umbrella release separately, only if it really happened.
- Exact unfinished gates, partial publication/deployment state, and next actions.
  Do not claim full readiness while any required gate is open. If no changes were
  needed, explicitly say no commit, tag, push, or release was created.

Update the automation's run checkpoint and its maintenance record with the
verified result, preserved pre-existing work, and remaining operations. Keep
machine-specific paths, credentials, and transient run journals outside public
guides. When changing the scheduled task, read its stored actual next-run
timestamp back and verify the local date/time in the intended IANA time zone;
the schedule label or recurrence text alone does not prove execution time.
