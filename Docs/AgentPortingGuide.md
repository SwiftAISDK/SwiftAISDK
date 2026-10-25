# Agent Porting Guide

This is the operational guide for agents porting Vercel AI SDK behavior into
SwiftAISDK. The rule is simple: update runtime behavior, tests, public docs, and
status docs together.

## Sources Of Truth

| Artifact | Role |
| --- | --- |
| `Docs/PortingStatus.md` | Current product status, active gaps, release-readiness checklist, and reopen rules. |
| `Porting/packages.json` and `Porting/upstream-lock.json` | Package/capability registration and reviewed npm baselines/provenance. Edit these structured inputs, then generate. |
| `Porting/README.md` | Catalog validation, package scaffolding, generation, compatibility CLI commands, and current migration limits. |
| `Docs/ProviderVersionLedger.md` | Generated npm package baseline table and Swift evidence index. |
| `Docs/CoreV6Parity.md` | Core `ai`, `@ai-sdk/provider`, `@ai-sdk/provider-utils`, and UI parity decisions. |
| `Docs/ProviderCapabilityMatrix.md` | Generated provider capability table. |
| `Sources/SwiftAISDK/Providers/ProviderCapabilityMatrix.swift` | Generated compiled capability inventory; tests check actual registry behavior. |
| `Docs/UpstreamTestInventory.md` | Generated upstream test/spec inventory. |
| `README.md` and `docs-site` | Public product documentation. |
| `AGENTS.md` | Repository-level agent rules. |
| `Docs/ModularizationPlan.md` | Package migration stages; execute one stage per run and inspect its recorded evidence. |
| `Docs/Migration/M0/README.md` | Frozen ownership/API inventory, extraction boundary register, and Swift 6.4 / exact-commit Swift 6.3.3 baseline evidence. |
| `Docs/Migration/M2/README.md` | Frozen core/module extraction evidence. |
| `Docs/Migration/M3/README.md` | Provider boundaries, standalone consumers and preserved migration evidence. |
| `Releases/README.md` and `Docs/Migration/M4/README.md` | Change records, deterministic exports, local release rehearsal and current verification evidence. |
| `Docs/Migration/M1/README.md` | Catalog import, generation/scaffold verification, and handoff to core extraction. |

## Standard Porting Flow

1. Pick a narrow scope: one large provider, one core surface, or a few related
   small providers.
2. Check the current baseline:

   ```sh
   Scripts/check-upstream-versions.js --all
   Scripts/check-upstream-versions.js --discover-packages --discover-kind provider,adapter,core
   ```

3. For changed packages, prepare upstream tarball diffs:

   ```sh
   Scripts/check-upstream-versions.js --package @ai-sdk/openai --prepare-diffs
   Scripts/check-upstream-versions.js --prepare-diffs
   ```

4. Read the generated `summary.md` and `upstream.diff` before editing Swift.
5. Read upstream tests before implementation files. Prefer upstream tests as the
   source of truth for observable behavior.
6. Patch the closest Swift implementation and keep the local architecture
   intact.
7. Add or update focused Swift tests.
8. Update public docs for changed user-facing behavior.
9. Update `Porting/upstream-lock.json` only after the baseline is reviewed; update
   capability metadata and per-package maps in the same pass. Run
   `node Scripts/sdk.mjs generate`, then update human-written status/parity docs
   for changed baselines, capabilities, or known gaps. Do not edit generated rows.
10. Run focused tests, then full verification.

Do not start a new batch until the current batch is implemented, tested,
documented, and committed/pushed if the user asked for that.

Before declaring a tooling or metadata change complete, run
`node Scripts/sdk.mjs generate --check` and
`node --test Scripts/tests/*.test.cjs`. Adding a selected provider starts
with `node Scripts/sdk.mjs package add --upstream @ai-sdk/name --module SwiftAIName`;
the result is explicitly unimplemented until its behavior and tests are ported.

## Upstream Reading Order

For a provider package, inspect in this order:

| Open first | Why |
| --- | --- |
| `*.test.ts`, `*.test-d.ts`, `*.spec.ts` | Request bodies, URLs, warnings, aliases, stream lifecycle, unsupported cases, and exact result expectations. |
| `index.ts` | Public exports, names, aliases, tools, and factory shape. |
| `*provider.ts` | Provider ID, base URL, auth, headers, env vars, and model routing. |
| `*language-model*.ts` | Prompt conversion, request body, parsing, tool calls, and streaming. |
| `*embedding*.ts`, `*rerank*.ts` | Batch limits, body shape, usage, and provider options. |
| `*image*.ts`, `*video*.ts`, `*speech*.ts`, `*transcription*.ts` | Media/audio routes, multipart fields, polling, downloads, warnings, and metadata. |
| `*tool*.ts` | Provider-defined tool names, beta headers, schema mapping, and result conversion. |
| Shared helpers under `packages/provider-utils` | Only when the provider imports helper behavior directly. |

If upstream tests and implementation disagree, mirror runtime behavior and add a
Swift test that documents the decision.

## Swift Translation Rules

- Keep provider IDs, factory names, aliases, default base URLs, env vars, auth
  headers, user-agent suffixes, and unsupported-model behavior aligned with
  upstream.
- Prefer typed Swift settings and provider option structs where upstream has a
  schema. Keep `extraBody` as the explicit low-level escape hatch.
- Build request bodies with structured `JSONValue`; avoid string assembly unless
  a provider API requires encoded payloads.
- Preserve text, reasoning, tool calls, sources, files, usage, finish reasons,
  response/request metadata, provider metadata, and raw chunks where upstream
  exposes them.
- Streams should emit lifecycle parts equivalent to upstream where Swift exposes
  the surface.
- Abort signals must flow through direct requests, streams, uploads, downloads,
  polling, retries, and retry sleeps.
- Provider failures should preserve status, headers, body details, and
  retryability through the shared error path.
- JS-only runtime behavior, TypeScript inference helpers, framework hooks,
  browser/Node response plumbing, and codemods are out of scope unless
  SwiftAISDK adds a matching product surface.

## Test Porting Requirements

Every upstream test file that maps to an in-scope Swift surface should end in
one of these states:

- `ported`: behavior is covered by a Swift test.
- `covered-by-existing-platform-test`: only for Swift platform behavior already
  proven by local tests.
- `out-of-scope`: JS/browser/Node/framework/codemod behavior or product surface
  SwiftAISDK does not expose.
- `blocked`: behavior requires a Swift API/product decision.

Translate behavior into idiomatic Swift tests. Do not copy JS structure
mechanically. Preserve Swift API differences, Foundation networking behavior,
Swift concurrency, typed errors, and existing test helpers.

Keep these local test categories even when upstream parity tests exist:

- live smoke tests behind `LIVE_AI_TESTS=1`;
- platform integration tests for stdio/process, Foundation URL handling,
  multipart encoding, Swift cancellation, and OS availability;
- Swift-only public API tests for typed `Codable` output, `Sendable` boundaries,
  provider capability inventory, and Swift metadata wrappers;
- shared test fixtures that are genuinely reused.

When adding translated tests:

- Use focused file names that describe the upstream behavior area.
- Prefer reviewable files under roughly 300-400 lines.
- Split by upstream `describe` block or behavior area, not by mechanical
  `Part1` / `Part2` names.
- Do not delete legacy local assertions until the corresponding upstream file
  has been inspected and classified.
- Record skipped upstream behavior in status/docs when the skip is a product
  decision, not merely an implementation TODO.

Refresh the upstream test inventory when the pass depends on current upstream
test lists:

```sh
Scripts/update-upstream-test-inventory.js
```

## Public Documentation Requirements

Public docs are part of the port. Update README/docs-site when a change affects:

- public API names or overloads;
- provider setup, env vars, base URLs, auth, aliases, or supported capabilities;
- request options, provider options, warnings, or unsupported settings;
- response result shapes, stream parts, metadata, usage, or errors;
- examples users are likely to copy;
- known limitations, Swift-specific differences, or troubleshooting steps.

Use `Docs/ProductDocumentation.md` for the docs quality bar and verification
commands.

## Verification

Run a focused filter that covers the changed package or core area:

```sh
swift test --package-path Packages/swift-ai-openai --filter openAI --no-parallel
```

Then run every extracted package and the aggregate. SwiftPM does not run tests
of dependency packages when testing the root:

```sh
node Scripts/test-packages.mjs
node Scripts/verify-core-isolation.mjs
node Scripts/verify-provider-isolation.mjs
node Scripts/verify-provider-versions.mjs
```

The root package is the temporary legacy aggregate. Core, Anthropic, generic
OpenAI-compatible and OpenAI changes belong in their catalog-owned `Packages/`
directories. Remaining providers, MCP and UI still live under `Sources/SwiftAISDK`.
Pure provider tests move with the provider; mixed integration and compatibility
tests remain in the root. Declare test-only products/resources in the module's
`testDependencies`/`testResources`, then regenerate. Register every source, test
and resource in its porting map; preserve existing upstream evidence dispositions.

Keep imports aligned with the catalog graph. Use package access for helpers
shared inside core; expose a public adapter API only when an independent provider
needs it. Neither core nor an extracted provider may import the aggregate. Typed
native `configuration:` factories and legacy `settings:` overloads are separate
entry points. Provider defaults remain in the owning module; legacy dispatch and
host-specific hooks stay in aggregate adapters until those hosts are extracted.

Edit core facade signatures, then regenerate `Compatibility.swift`; do not edit
its generated methods or duplicate their runtime bodies. Legacy default-provider
resolution stays in the aggregate. Keep pure model/registry clients independent
of implicit Gateway initialization. Public symbol comparison checks source
surface preservation, not ABI compatibility across module moves.

For docs-site changes:

```sh
npm ci --prefix docs-site
npm --prefix docs-site run check
npm --prefix docs-site run build
```

Optional live smoke:

```sh
LIVE_AI_TESTS=1 swift test --filter LiveProviderSmoke
```

## Completion Summary

When finishing a porting pass, summarize:

- upstream package versions or commit inspected;
- Swift runtime behavior changed;
- upstream tests translated or classified out of scope;
- public docs updated;
- status/ledger docs updated;
- exact test commands and results.

## Modular release rehearsal

Record reviewed Swift changes in `Releases/changes/`; keep npm baselines in the
upstream lock. Run `release plan`, `release export --dry-run`, and the complete
`node Scripts/verify-release-rehearsal.mjs` gate described in `Releases/README.md`.
The plan must be regenerated after input changes. Dirty working-tree exports are
explicit previews with a null canonical source commit.

Exports use catalog-owned source/test roots and preserve source bytes. Do not add
manual fixes to exported repositories. Fix the canonical package, metadata or
renderer and regenerate. Retain imported provenance gaps and canonical-only
integration mappings; do not promote them to parity proof because packaging passes.

The reusable `.github/workflows/package-check.yml` is the single standalone CI
recipe; every exported repository receives the same bytes and a minimal caller.
It uploads no artifacts. Actual remote publication, minimum hosted compiler proof
and finalized release-set records remain M5 gates. A local rehearsal never creates
a `published` record in the canonical `Releases/sets/` directory.
