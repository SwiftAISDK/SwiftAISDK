# Repository Agent Guide

This repository is a SwiftPM port of the provider-facing Vercel AI SDK surface.
When acting as an agent here, keep code, tests, public docs, and porting status
in sync in the same change.

## Workflow

- Work on the current branch by default. Do not create a branch or PR unless the
  user asks for one.
- Prefer a small, vertical batch: one large provider, one core surface, or a few
  related small providers.
- Before changing behavior, read the nearest Swift implementation, existing
  tests, upstream package source, and upstream tests.
- Port behavior, then tests, then public docs/status docs. Do not leave docs as
  a follow-up when public behavior changes.
- Commit and deploy/push directly from the current branch only when the user
  asks. If rollback is needed, prefer returning to an older commit over adding a
  branch workflow.
- For release-style pushes, bump the release tag first: inspect the latest
  semantic-version tag, create the next appropriate annotated tag on the commit
  being released, then push the branch and tag together.
- Modular releases follow `Releases/README.md`: edit canonical source, publish
  deterministic exports in dependency order, and tag only changed release units.
  A provider-only release does not require a new umbrella tag. Distribution
  repositories must never receive hand-edited implementation fixes.

## Commit Messages

Use the configured human Git author and committer identity. In the maintainer's
checkout this is `Nikolay Solovyov <i@mr-ozio.ru>`; outside contributors keep
their own human identity. Check `git var GIT_AUTHOR_IDENT` and
`git var GIT_COMMITTER_IDENT` before committing. Do not replace either identity
with an agent/model identity, pass an AI `--author`, or inject AI author/committer
environment variables.

Do not append AI `Co-authored-by`, `Signed-off-by`, generated-by footers, session
links, or similar tool attribution to commits or PRs. Preserve genuine human
coauthors and upstream legal notices. Follow the project attribution settings in
`.claude/settings.json`; apply this rule to every agent, not just Claude.

Use `<type>(<scope>): <summary>` for new commits. Write the subject in English,
use the imperative mood, omit a trailing period, and aim for 72 characters or
fewer. Name the concrete change and its affected surface; avoid generic subjects
such as `Update AI SDK upstream port`, `Fix bugs`, or `Update docs`.

- Types: `feat` for added behavior, `fix` for corrections, `docs` for documentation,
  `refactor` for restructuring without behavior changes, `perf` for performance,
  `test` for tests, `build` for dependencies/tooling, `ci` for CI, `chore` for
  maintenance, `release` for release preparation/records, and `revert` for rollbacks.
- Scope: use the affected provider (`openai`, `anthropic`), shared surface (`core`,
  `mcp`, `ui`), or area (`readme`, `docs-site`, `porting`, `release`). For a coherent
  multi-provider sync, use `upstream` and summarize the main behavior in the subject.
- Choose the type from the primary outcome. A feature commit includes its tests
  and docs under `feat`; split unrelated changes into separate commits. Mark a
  breaking change with `!` before `:` and explain the migration in the body.
- For a substantial port, use the body to record package/baseline changes,
  compatibility limits, and actual validation results. Keep detailed version
  inventories and evidence in the linked audit/release records.
- Release subjects name the unit/version and action. Say `prepare`, `publish`, or
  `record` according to what the commit actually establishes; claim publication
  or verification only when the corresponding evidence exists. Commit types do
  not replace the version/bump decisions in `Releases/README.md`.

Examples:

```text
feat(openai): Add Responses tool allow-lists
fix(core): Preserve tool result order under concurrency
docs(readme): Shorten onboarding and link feature guides
chore(upstream): Refresh provider baselines and test inventory
release(umbrella): Prepare SwiftAISDK 3.3.0
```

## Documentation Structure

- Keep root `README.md` a short entry point: overview, requirements, installation,
  one quick-start example, a compact guide index, development links, and license.
  Keep it within 150 lines. Improve existing sections before adding new ones.
- A new feature or provider normally updates its owning docs-site guide and
  example, not README. Change README only when onboarding, installation, package
  selection, or a top-level navigation link changes.
- Put API options, stream/error contracts, provider details, limitations, and
  additional examples in `docs-site/src/content/docs`. Keep version/baseline
  tables, parity evidence, audit history, and release notes in the owning `Docs/`
  or `Releases/` records. Do not append feature announcements or audit summaries
  to README or duplicate full provider/version lists there.
- Link to the authoritative guide instead of copying it. When trimming README,
  preserve useful guidance in its owning document and check the replacement link.
- Follow `Docs/ProductDocumentation.md` for ownership and verification. Review
  README's length and links whenever editing it; a public behavior change does
  not by itself require a README edit.

## Porting Requirements

- Read `CONTRIBUTING.md` for contributor setup and review expectations. Weekly
  updates must follow the complete `Docs/WeeklyUpstreamUpdate.md` playbook as well
  as this file; keep the scheduled task's prompt aligned with these instructions.
- Use `Docs/AgentPortingGuide.md` as the operational playbook.
- Use `Docs/PortingStatus.md` for the current product and porting state.
- Use `Docs/ProviderVersionLedger.md` for npm package baselines.
- Use `Docs/ProviderCapabilityMatrix.md` and
  `Sources/SwiftAISDK/Providers/ProviderCapabilityMatrix.swift` for provider
  coverage.
- Use `Docs/UpstreamTestInventory.md` before porting tests from upstream.
- During an upstream porting pass, implement newly discovered provider packages
  and provider components immediately, without additional user confirmation.
  Complete runtime, tests, catalog/capabilities, public docs and release metadata
  in the same pass; discovery or scaffolding alone is not a completed port.
- For new providers and all other ported packages, acceptance is driven first by
  their matching-release upstream tests translated into Swift. Preserve scenarios,
  fixtures, expected results and assertions; local tests supplement this evidence.
  Port every test covering the Swift surface and document genuine platform-only
  exclusions. Missing release evidence or failing required tests remain open gates.

Every porting pass must update:

1. Swift runtime behavior.
2. Focused Swift tests translated from upstream behavior.
3. Public docs when public API, provider behavior, examples, result shapes, or
   limitations change.
4. Porting status/version docs when upstream baselines, coverage, or known gaps
   change.

## Verification

- Run the narrowest useful package test first, for example
  `swift test --package-path Packages/swift-ai-openai --filter ... --no-parallel`.
- Use `node Scripts/sdk.mjs dev test --filter ... --no-parallel` for compatibility
  tests against current local sources. The root manifest resolves public tags.
- Run `node Scripts/test-packages.mjs` before calling a behavior port complete;
  it runs every package suite and the complete compatibility suite. A root-only
  `swift test` does not run dependency-package tests.
- For docs-site changes, run:

  ```sh
  npm ci --prefix docs-site
  npm --prefix docs-site run check
  npm --prefix docs-site run build
  ```

- Optional live checks stay behind `LIVE_AI_TESTS=1`.
- Keep Actions artifact uploads limited to the documentation deployment handoff
  on `main`, with one-day retention. Pull request checks must not upload artifacts.
