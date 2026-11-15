# Product Documentation

SwiftAISDK should be documented as a usable Swift package, not as a pile of
ported methods. Public documentation must explain what the product does, how the
major workflows behave, what providers return, and where Swift intentionally
differs from the TypeScript AI SDK.

## Public Surfaces

| Surface | Role | Update when |
| --- | --- | --- |
| `README.md` | Fast orientation, install, quick start, and links to the deeper docs. | A new user would otherwise miss the package shape or the right next link. |
| `docs-site/src/content/docs` | User-facing product docs: guides, cookbook, providers, reference, parity, and troubleshooting. | Public API, examples, provider behavior, result shapes, errors, or limitations change. |
| `Docs/ProviderCapabilityMatrix.md` | Generated provider and capability table. | `AIProviderCapabilities` changes. |
| `docs-site/src/content/docs/reference/generated` | Generated symbol/reference docs. | Public Swift symbols change and docs generation is run. |
| `Examples` | Runnable examples that prove guide code. | A documented workflow needs compile-checked sample code. |
| `skills/swiftaisdk/SKILL.md` | Installable coding-agent skill that points agents at the API and the Markdown docs. | API names, install steps, or docs URLs used in its snippets change. |
| `docs-site/public/llms.txt`, `llms/**` and `<page>.md` routes | Generated Markdown copies of every page for coding agents. | Regenerated with the docs site; never edit by hand. |

## README Boundaries

Keep the root README within 150 lines. It is the entry point for a new user:
overview, requirements, install, one quick-start example, a compact guide index,
development links, and license. Update it when onboarding, installation, package
selection, or top-level navigation changes.

New features and providers belong in their owning docs-site guides and runnable
examples. Link to those guides from an existing navigation row when needed;
do not add a README section for every addition. Keep detailed API contracts,
provider options, troubleshooting, and extra snippets in docs-site. Keep package
inventories, upstream baselines, parity evidence, audit history, and release notes
in the owning Docs or Releases records. When shortening README, preserve unique
guidance in its owning page and verify the replacement links.

## Generated Docs-Site Pages

`npm --prefix docs-site run generate` (also run by `check`, `build` and `dev`)
executes `docs-site/scripts/generate-docs.mjs`. It deletes and rewrites these
files, so edit their inputs instead:

| Generated output | Edit instead |
| --- | --- |
| `providers/index.mdx` and `providers/<provider>.mdx` | Capability rows in `Porting/packages.json` (`displayName`, `credentials`, and `notes` as a short current-behavior summary); hand-written provider sections in `docs-site/scripts/provider-guides/<provider-slug>.md`; install versions come from the newest `Releases/umbrella/*.json` |
| `components/**` | Swift doc symbols; hand-written component sections in `docs-site/scripts/component-guides/<component-slug>.md` |
| `reference/generated/public-symbols.mdx` | Public Swift declarations |
| `getting-started/migrating-to-3.mdx` | `Docs/Migration.md` |
| `public/llms.txt` and `public/llms/**` | The source pages above and the hand-written `.mdx` pages |

All other pages under `docs-site/src/content/docs` and the sidebar in
`docs-site/astro.config.mjs` are hand-written. Add a new hand-written page to
the sidebar group that matches its task. Link between pages with relative links
(`../tools/`), never root-relative links (`/core/tools/`): the site is deployed
under `/SwiftAISDK`.

## Provider Pages And Package READMEs

Each provider capability row in `Porting/packages.json` carries:

- `displayName`: the product name used as the page title and in the provider list;
- `credentials`: every environment variable the Swift source reads, with its purpose;
- `notes`: one to three sentences of current behavior. Never append dated pass
  history; record it in `Docs/Archive/` instead.

Each `provider-guides/<slug>.md` starts with `## Quick start` (umbrella
`import SwiftAISDK` + `AIProviders.<factory>()`, a model ID that appears in the
package source or tests, and one call for the primary capability), followed by
task-oriented sections such as provider options, streaming or limitations. Every
snippet must compile; native-API snippets include `import SwiftAI` and the
provider module.

`Packages/<package>/README.md` becomes the "Authored usage guide" of the exported
distribution README. Keep it short: what the module adds, links to its provider
guide pages, a native-API snippet that creates the provider, the credentials it
reads, and a pointer to the canonical repository for contributions. Usage details
belong in the provider guide, not the README.

## What Belongs In Public Docs

Good product docs include:

- the user goal and the Swift entry point;
- runnable Swift snippets;
- the important request options and defaults;
- the shape of the returned result, stream parts, warnings, metadata, or errors;
- provider-specific differences when they affect user code;
- links to deeper reference instead of long method catalogs.

Avoid duplicating every test assertion in public docs. Put precise parity and
version evidence in `Docs/PortingStatus.md`, `Docs/ProviderVersionLedger.md`,
`Docs/CoreV6Parity.md`, and tests.

## Required Guide Coverage

The package docs should cover these product areas:

- install and quick start;
- generate text and stream text;
- structured output with `Output`, object, array, enum, and JSON strategies;
- tools, approvals, provider-defined tools, and MCP tools;
- embeddings, reranking, images, video, speech, transcription, audio generation,
  audio transformation, dubbing, file uploads, and skill uploads;
- provider setup, environment variables, provider options, and capability
  discovery;
- middleware, retries, aborts, telemetry, warnings, metadata, and errors;
- chat/UI message helpers and Swift-native agent surfaces;
- troubleshooting and live smoke testing.

## Documentation Definition Of Done

A change that affects public behavior is complete only when:

1. README remains within its entry-point scope and still points users to the
   right docs; most feature changes do not need a README edit.
2. docs-site has a guide, provider page, cookbook entry, or troubleshooting note
   for the changed user-facing behavior.
3. Result shapes, stream parts, warnings, metadata, and known limitations are
   described where users will look for them.
4. Generated docs are refreshed when generated sources change.
5. Porting/status docs are updated when upstream baselines or known gaps change.

Verification commands for docs-site changes (the variables match the published
base path, so broken base-relative links show up locally):

```sh
npm ci --prefix docs-site
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://swiftaisdk.github.io npm --prefix docs-site run check
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://swiftaisdk.github.io npm --prefix docs-site run build
```

For docs-only changes, run the docs-site build at minimum. For behavior changes,
run the focused package test first, then `node Scripts/test-packages.mjs` before
finishing; a root `swift test` does not run the dependency-package suites (see
[AGENTS.md](../AGENTS.md#verification)).
