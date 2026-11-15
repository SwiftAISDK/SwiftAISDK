# Contributing to SwiftAISDK

SwiftAISDK ports the provider-facing Vercel AI SDK surface to SwiftPM packages.
Contributions should keep runtime behavior, tests, public documentation, and
porting metadata consistent in one reviewable change.

## Find the right place

| Change | Owning location |
| --- | --- |
| Core orchestration, contracts, transport, shared utilities | `Packages/swift-ai-core` |
| Provider implementation and focused tests | Its `Packages/swift-ai-*` directory |
| MCP or native chat state | `Packages/swift-ai-mcp` or `Packages/swift-ai-ui` |
| Compatibility facade and mixed-provider integration | `Sources/SwiftAISDK` and `Tests/SwiftAISDKTests` |
| Product guides and provider instructions | `docs-site/src/content/docs` |
| Package identities, capabilities, ownership | `Porting/packages.json` and package `Porting/map.json` files |
| Reviewed npm baselines and provenance | `Porting/upstream-lock.json` |

This repository is the canonical source. The independent SwiftAISDK organization
repositories are generated distribution outputs. Submit implementation changes
here; maintainers publish them through the [release pipeline](Releases/README.md).

## Set up local development

Use a macOS/Xcode environment with Swift 6.3 or later. Hosted release verification
currently pins Swift 6.3.3; see the [runner guide](Docs/M3Runner.md). Use the Node
and npm requirements in [docs-site/package.json](docs-site/package.json) for
documentation work. Catalog generation uses the active Xcode Swift parser.

```sh
git clone https://github.com/SwiftAISDK/SwiftAISDK.git
cd SwiftAISDK
node Scripts/sdk.mjs dev build
```

The root `Package.swift` resolves published Git dependencies. The `dev` wrapper
creates an ignored workspace using the current local package sources. A root
`swift test` alone does not test the dependency packages you just edited.

Read [AGENTS.md](AGENTS.md) for repository rules and
[Docs/AgentPortingGuide.md](Docs/AgentPortingGuide.md) before porting behavior.

## Plan a focused contribution

- Report bugs with the affected Swift package/version, platform, a minimal
  reproduction, expected behavior, and redacted errors or stream events.
- Keep changes focused on one behavior, provider, shared surface, or related set.
  Include compatibility and migration effects in the description.
- Before implementation, read the owning Swift code/tests and the matching
  published upstream source/tests. Port observable behavior into Swift idioms.
- Keep upstream fixtures, scenarios, assertions, errors, and lifecycle checks.
  Local tests supplement upstream evidence. Record justified platform exclusions
  and unresolved matching-release evidence; do not describe missing coverage as parity.
- Preserve existing local changes and coordinate overlapping work. Do not stage
  another task's edits merely because they are in the same file.

External contributors can submit a pull request from their fork. Agents working
in the maintainer's checkout use the current branch and create a branch or PR
only when requested. Commit, push, and publication require the authorization
described in [AGENTS.md](AGENTS.md); a contribution is not release permission.

## Validate the change

Start with the owning package and a focused compatibility filter:

```sh
swift test --package-path Packages/swift-ai-openai --filter openAI --no-parallel
node Scripts/sdk.mjs dev test --filter yourFocusedTest --no-parallel
```

Before calling a behavior port complete, run every package suite and the full
compatibility suite:

```sh
node Scripts/test-packages.mjs
```

For catalog, generation, or tooling changes:

```sh
node Scripts/sdk.mjs generate --check
node --test Scripts/tests/*.test.cjs
```

The [porting guide](Docs/AgentPortingGuide.md) and
[weekly update playbook](Docs/WeeklyUpstreamUpdate.md) define additional isolation,
dependency, export, minimum-version, iOS, example, and release checks.
Run checks appropriate to the changed surface; record the actual commands and
results. Live provider tests are optional, require `LIVE_AI_TESTS=1`, and may
incur charges. Mock-backed validation does not require provider credentials.

For docs-site changes:

```sh
npm ci --prefix docs-site
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://swiftaisdk.github.io npm --prefix docs-site run check
DOCS_BASE=/SwiftAISDK DOCS_SITE=https://swiftaisdk.github.io npm --prefix docs-site run build
```

Preview a built site with:

```sh
DOCS_BASE=/SwiftAISDK npm --prefix docs-site run preview
```

Check whitespace and review the staged patch before committing:

```sh
git diff --check
git diff --cached
```

## Keep documentation in its owning place

Keep README within 150 lines: orientation, installation, one quick start, and
navigation. Put feature details, options, result shapes, stream contracts, errors,
and limitations in the relevant guide. Put version inventories, audit evidence,
and release history in the owning `Docs/` or `Releases/` records.

Update structured catalog/provenance inputs before regenerating derived files;
do not hand-edit generated tables, compatibility methods, or exported packages.
Preserve upstream license notices and fixture provenance. See the
[documentation contract](Docs/ProductDocumentation.md).

## Name commits and preserve human attribution

Use `<type>(<scope>): <summary>` with a concrete English imperative subject,
normally at most 72 characters, without a final period. For example:

```text
fix(openai): Preserve tool result metadata in Responses history
docs(contributing): Explain local validation and porting workflow
```

[AGENTS.md](AGENTS.md#commit-messages) defines types, scopes, breaking changes,
release subjects, and commit bodies. Summarize the behavior and why it changed;
put detailed package inventories and verification evidence in the owning reports.

Commits belong to the human contributor using the checkout's configured Git
identity. AI tools must not replace that identity with their own or append AI
`Co-authored-by`, `Signed-off-by`, generated-by footers, or session links.
Real human coauthors and upstream legal notices retain their attribution.
In the maintainer's checkout, the configured human identity is
`Nikolay Solovyov <i@mr-ozio.ru>`; outside contributors use their own identity.
The project [.claude/settings.json](.claude/settings.json) disables automatic
commit/PR attribution and session links using Claude Code's
[attribution settings](https://code.claude.com/docs/en/settings-reference#attribution).

## Make review straightforward

Describe the concrete trigger and resulting behavior, compatibility implications,
matching-release upstream evidence, checks run, and any remaining limitations.
Keep claims proportional to the evidence: a reviewed npm baseline, mock test,
local rehearsal, hosted CI, and live provider call prove different things.

Maintainers use the [weekly playbook](Docs/WeeklyUpstreamUpdate.md) for upstream
refreshes and the [release workflow](Releases/README.md) for publication. Changed
providers can release independently; a provider-only change does not automatically
require an umbrella release or a bump to unchanged packages.
