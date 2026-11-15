# Dedicated M3 verification runner

The canonical workflow prefers the dedicated SwiftAISDK runner on **OZ.m3** for
trusted `push` and `workflow_dispatch` events at `refs/heads/main`. Its labels are
`self-hosted`, `macOS`, `ARM64`, and `swift-ai-m3`. Every pull request and other
ref uses GitHub-hosted `macos-26`. Select `runner=github` to force hosted execution.
Other CI jobs retain their own workflow routing.

The dedicated runner service lives at
`~/Library/Developer/SwiftAISDK/ActionsRunner`. It is separate from the existing
Viscacha runner and its service, labels and working directory; installing or
restarting SwiftAISDK's runner does not require changing Viscacha. GitHub routes
jobs to an online, idle runner with all matching labels. An unavailable matching
runner otherwise leaves the job queued. See [GitHub's self-hosted runner routing
reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).

## Queue fallback

The parallel `m3_watchdog` job runs on `ubuntu-latest`. It polls this workflow
run's target job (`test`, or `runner_probe` for a smoke run) every ten seconds.
The grace period begins when the target is first observed queued. If it remains
queued for **90 seconds**, the watchdog checks that `main` still points to the
original `GITHUB_SHA`, then fetches the target's status again. Only a still-queued
target at that source revision triggers one dispatch of the same `docs.yml`:

- Canonical checks: `scope=all`, `runner=github`.
- Runner smoke checks: `scope=runner`, `runner=github`.
- Both include `fallback_from=<original run ID>` in the replacement run's inputs
  and name so the handoff remains traceable.

The existing `main` concurrency group cancels the original waiting run when the
replacement starts. The hosted run explicitly selects GitHub and cannot create
another M3 fallback. The watchdog uses only the job's short-lived `GH_TOKEN`
(the workflow's `GITHUB_TOKEN`) with `actions: write`; it needs no administrator
runner inventory API, PAT, permanent token, heartbeat or additional secret.
GitHub explicitly permits workflow dispatches made with `GITHUB_TOKEN` to create
workflow runs. See [triggering a workflow from a
workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

The watchdog exits without dispatch when the target starts, completes, fails,
waits for approval, or the source is superseded. Actual test failures remain
failures. Missing targets stop after a five-minute polling bound; API errors fail
closed. Each API request has a 15-second timeout. A lost dispatch response is
ambiguous and is **never retried automatically**: reconcile the source SHA and
`fallback_from` run name before taking further action.

## Pinned Swift and compatible SDK without system changes

Install the official Swift **6.3.3** package side by side in the runner account's
`~/Library/Developer/Toolchains/` directory. Swift's installer supports a
user-home installation; verify the official installer signature before use.
See [Swift's macOS package installer
instructions](https://www.swift.org/install/macos/package_installer/).

`node Scripts/m3-runner.cjs prepare` runs only when
`RUNNER_ENVIRONMENT=self-hosted`. It finds a `*6.3.3*.xctoolchain`, checks the
actual compiler reports exactly Swift 6.3.3, and requires one matching verified
toolchain. It appends that toolchain's `usr/bin` to `GITHUB_PATH` and its
`CFBundleIdentifier` as `TOOLCHAINS` to `GITHUB_ENV`.

The self-hosted macOS SDK is pinned separately from the installed Xcode. The
default is `/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`; set
`SWIFT_M3_MACOS_SDKROOT` to an absolute SDK directory to override it. Preparation
checks the directory and macOS SDK manifest, then uses the selected Swift 6.3.3
compiler to typecheck `import Foundation` and `import CryptoKit` against it. Only
after that succeeds does it export `SDKROOT` in the job's `GITHUB_ENV` alongside
`TOOLCHAINS`. An incompatible or missing SDK fails preparation before any exports.

This compiler/SDK pairing matters: M3 verification found that the installed
Xcode 27 macOS 27 SDK produces an unknown `-target-arch-variant` option and missing
CryptoKit with the pinned 6.3.3 compiler. The existing Command Line Tools macOS
26.5 SDK passed the Foundation/CryptoKit smoke. iOS verification still selects
the workflow's explicit simulator SDK; its smoke was checked separately.

Subsequent steps use the pinned compiler, compatible macOS SDK and the workflow's
runner-specific `DEVELOPER_DIR`. Preparation does not change `xcode-select`,
the system Swift binary, the installed Xcode or another project's settings.
Hosted preparation is a no-op; the workflow continues to check hosted Swift
6.3.3 independently.

## Manual execution and evidence

Force a complete hosted verification:

```sh
gh workflow run docs.yml --ref main -f scope=all -f runner=github
```

Exercise runner selection and toolchain preparation without the SDK suite:

```sh
gh workflow run docs.yml --ref main -f scope=runner -f runner=auto
```

The smoke job is named **`runner_probe`**. Its success proves runner/toolchain
smoke behavior only. It is **not release evidence**: canonical publication still
requires the executed **`test`** job to succeed at the exact source SHA, including
the workflow's normal package, compatibility, iOS and example checks.

`Scripts/m3-runner.cjs` exposes three commands:

| Command | Inputs and effects |
| --- | --- |
| `select` | Reads `GITHUB_EVENT_NAME`, `GITHUB_REF`, `RUNNER_PREFERENCE`; appends JSON `labels` and `kind=m3\|github` to `GITHUB_OUTPUT`. |
| `prepare` | Uses `RUNNER_ENVIRONMENT`, the runner account's home, optional `SWIFT_M3_MACOS_SDKROOT` and Actions environment files; validates the compiler/SDK pair and exports job-only `PATH`, `TOOLCHAINS` and `SDKROOT`. |
| `watch` | Uses `GH_TOKEN`, `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`, `GITHUB_SHA`, routing variables and `WATCH_JOB_NAME`; observes queue status and may dispatch one hosted replacement. |

The exported `watchQueuedJob` accepts injected API, clock and sleep functions.
Focused tests run without network requests, real delays or Swift processes:

```sh
node --test Scripts/tests/m3-runner.test.cjs
```
