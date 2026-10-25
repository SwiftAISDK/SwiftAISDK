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

## Porting Requirements

- Use `Docs/AgentPortingGuide.md` as the operational playbook.
- Use `Docs/PortingStatus.md` for the current product and porting state.
- Use `Docs/ProviderVersionLedger.md` for npm package baselines.
- Use `Docs/ProviderCapabilityMatrix.md` and
  `Sources/SwiftAISDK/Providers/ProviderCapabilityMatrix.swift` for provider
  coverage.
- Use `Docs/UpstreamTestInventory.md` before porting tests from upstream.

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
