# M5: organization and initial modular releases

Status: **complete**. Started 2026-10-25; completed 2026-10-26 (Asia/Tokyo).
M6 has not started. The canonical root has no new release tag; 3.0 belongs to M7.

## Published result

The [SwiftAISDK organization](https://github.com/SwiftAISDK) is on GitHub Free,
with `ozio` as owner (organization ID 347859412). The canonical repository was
transferred to [SwiftAISDK/SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK),
preserving repository ID 1254813083, all 67 tag refs and all 24 existing Release IDs.
Both old and new Git URLs return the same historical tags. A fresh SwiftPM client
still resolves 2.8.1 through the old URL to its original `fc4e5dc` commit.
See [transfer.json](transfer.json) and [legacy-consumer.json](legacy-consumer.json).

| Distribution | Swift version | Export commit | Annotated tag object |
| --- | --- | --- | --- |
| [swift-ai-core](https://github.com/SwiftAISDK/swift-ai-core/releases/tag/1.0.0) | 1.0.0 | `0e80d5a02bcc` | `6858b54deea1` |
| [swift-ai-anthropic](https://github.com/SwiftAISDK/swift-ai-anthropic/releases/tag/1.0.0) | 1.0.0 | `c7f5099e3949` | `6630aa9c8705` |
| [swift-ai-openai-compatible](https://github.com/SwiftAISDK/swift-ai-openai-compatible/releases/tag/1.0.0) | 1.0.0 | `7c6d26317ac8` | `0d663d37cacd` |
| [swift-ai-openai](https://github.com/SwiftAISDK/swift-ai-openai/releases/tag/1.0.0) | 1.0.0 | `7bb202cb77dd` | `482221270891` |

All four packages derive from canonical source [`f91f47882eba`](https://github.com/SwiftAISDK/SwiftAISDK/commit/f91f47882ebaba0d602474fdd5ddc9f249eecce2).
Their public manifests use compatible Git dependency ranges. Every repository has
its own changelog, attribution/license, canonical commit, npm provenance subset,
port map, tests and shared CI recipe. Sources are edited only in the canonical
repository. The full immutable record is [Releases/sets/modular-pilot.json](../../../Releases/sets/modular-pilot.json).

## Verification

- [Canonical hosted workflow](https://github.com/SwiftAISDK/SwiftAISDK/actions/runs/40205295468) passed on the exact release source,
  with the explicitly checked Apple Swift 6.3.3 compiler from Xcode 26.6.
- Full Swift test job: 3545 reported tests (126 core, 135 Anthropic, 7 compatible,
  270 OpenAI and 3007 aggregate), including 33 explicit live-test skips.
- Local tooling: 20 tests passed, no failures or skips. Exporting the committed
  source twice produced identical manifests and hashes for 318 files.
- Canonical CI also verifies isolated clients, independent version selection,
  complete local publication rehearsal, existing examples, offline MCP OAuth,
  documentation diagnostics/build and Pages deployment.
- [SwiftAISDK/swift-ai-core CI](https://github.com/SwiftAISDK/swift-ai-core/actions/runs/40207607505): exact export commit `0e80d5a02bcc`, successful.
- [SwiftAISDK/swift-ai-anthropic CI](https://github.com/SwiftAISDK/swift-ai-anthropic/actions/runs/40207630862): exact export commit `c7f5099e3949`, successful.
- [SwiftAISDK/swift-ai-openai-compatible CI](https://github.com/SwiftAISDK/swift-ai-openai-compatible/actions/runs/40207656993): exact export commit `7c6d26317ac8`, successful.
- [SwiftAISDK/swift-ai-openai CI](https://github.com/SwiftAISDK/swift-ai-openai/actions/runs/40207684506): exact export commit `7bb202cb77dd`, successful.
- Five fresh external clients resolve and execute against the actual public tags:
  CoreOnly, AnthropicOnly, OpenAICompatibleOnly, OpenAIOnly and MixedProviders.
  They use no local package dependencies or SwiftPM mirrors. Local client compiler
  details and exact lockfiles are in [public-consumers.json](public-consumers.json).
  The [mixed-client lockfile](MixedProviders.Package.resolved) is usable installation
  evidence; earlier M3/M4 lockfiles remain disposable local fixtures.
- M5 changes no runtime or Swift test source bytes relative to the committed
  M0–M4 migration. No new provider behavior, npm baseline or capability is claimed.

Publication uses a separately validated production export, exact-source hosted CI,
annotated tags and atomic branch/tag pushes in dependency order. Fresh remote
clones verify file hashes; remote branch/tag/peeled refs and GitHub Release targets
are read back. Retries inspect actual refs and refuse conflicts. Repository tag
rulesets prohibit updates/deletion without bypass actors. Tests cover interruption
after push, resumption, conflicting tags and already-consumed production history.

## Documentation and infrastructure

Documentation is served at [swiftaisdk.github.io/SwiftAISDK](https://swiftaisdk.github.io/SwiftAISDK/).
The `ozio/ozio.github.io` redirect site preserves 97 old content paths and text
reference files. A native Zen browser check followed an old streaming-speech URL
to the corresponding new page while retaining its query string and fragment.
The old `ozio/SwiftAISDK` name has not been recreated, preserving GitHub's Git redirect.

Actions/Pages and the main-only deployment environment remain enabled. Artifact
uploads are limited to documentation handoff on main with one-day retention;
distribution CI uploads no artifacts. The authorized local GitHub CLI/SSH identity
performs publication; there is no cross-repository write secret stored in Actions.

## Port provenance and scope

All six pinned pilot npm archives were re-downloaded and SHA-512 verified against
the lock: `ai`, provider, provider-utils, Anthropic, compatible and OpenAI. Published
TypeScript declarations were reviewed for factory/protocol families. The records
omit `gitHead`; the inherited test snapshot remains explicitly
`inventory-snapshot-not-release-verified`. Archive integrity is not matching-test
proof. See [upstream-review.json](upstream-review.json).

Native Swift `Sendable` protocols, async/throwing operations, async streams and
typed configurations define the adapter contract. Existing upstream behavior and
documented gaps remain; packaging does not imply new or complete parity. Swift
versions are independent of npm versions. SwiftPM resolves one version of each
package identity, requiring compatible shared-core constraints.

M6 owns remaining provider/MCP/UI extraction. M7 owns the modular aggregate and
3.0 migration. The existing tagged 2.x aggregate remains installable.

Machine-readable release, hosted CI and infrastructure evidence is in
[verification.json](verification.json).
