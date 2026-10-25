# M3: Anthropic, compatible and OpenAI provider pilot

Date: 2026-10-25. Status: **complete**. Next stage: M4.

This stage extracts three independently buildable provider packages while
preserving the existing SwiftAISDK facade. It advances the
[migration plan](../../ModularizationPlan.md), not the reviewed upstream versions.
No organization, repository transfer or modular release is created here.
M0–M2 evidence remains frozen.

## Package boundary

| Package / module | Runtime Swift files | Runtime dependencies |
| --- | ---: | --- |
| `swift-ai-core` / `SwiftAIProvider` | 30 | Foundation |
| `swift-ai-core` / `SwiftAITransport` | 11 | SwiftAIProvider |
| `swift-ai-core` / `SwiftAIProviderUtilities` | 28 | Contracts and transport |
| `swift-ai-core` / `SwiftAI` | 61 | The three lower core modules |
| `swift-ai-anthropic` / `SwiftAIAnthropic` | 10 | Contracts, transport and utilities |
| `swift-ai-openai-compatible` / `SwiftAIOpenAICompatible` | 9 | Contracts, transport and utilities |
| `swift-ai-openai` / `SwiftAIOpenAI` | 20 | Contracts, transport, utilities and compatible |
| Root compatibility module `SwiftAISDK` | 193 | Core and all three extracted provider products |

The catalog owns manifests and dependency edges. Native providers have no runtime
import of `SwiftAI`, `SwiftAISDK`, MCP, UI or unrelated provider implementations.
Tests may depend on the orchestration product through explicit test-only module
dependencies. Core remains provider-independent.

OpenAI deliberately depends on the generic compatible package for the existing
shared chat/completion, embedding and image wire implementations. Upstream's
separate implementations do not require duplicating that Swift code. This adds
a compatible-package version constraint to OpenAI, but introduces no dependency
from compatible to OpenAI. Native OpenAI policy, Responses, audio, Live, file
management and skills remain owned by OpenAI. A future incompatible wire change
must respect both packages' version contracts; it must not silently change the
shared engine for every consumer.

## Runtime and compatibility decisions

- Provider settings are typed: `AnthropicProviderSettings`,
  `OpenAICompatibleProviderSettings` and `OpenAIProviderSettings`. Native factories
  extend the core `AIProviders` namespace using the `configuration:` label.
  Native clients pass model objects or build an explicit provider registry.
- The generic compatible factory takes its name/base URL explicitly. It has no
  built-in provider dispatch, environment lookup or implicit default provider.
  OpenAI and Anthropic retain their own authentication, endpoint defaults and
  user-agent versions. The reviewed baselines remain Anthropic 4.0.88,
  OpenAI-compatible 3.0.78 and OpenAI 4.0.102.
- The legacy `SwiftAISDK` factory namespace, broad `ProviderSettings`, return
  types, defaults and `settings:` initializers remain available through adapters
  and re-exports. In particular, the old OpenAI factory still returns
  `SwiftAISDK.OpenAICompatibleProvider`; the native factory returns `OpenAIProvider`.
  The generic native compatible class and the legacy dispatch class are distinct.
  Qualify names when importing both surfaces.
- Bedrock/Vertex hosting code stays in the aggregate. MiniMax Messages adjustments,
  xAI Responses preparation/error handling, provider-specific chat options and
  Gateway errors are injected through typed adapter hooks. Neither extracted
  provider imports these concrete implementations. Existing provider-ID protocol
  conventions in shared parsers are retained; extraction does not claim to remove
  every historical provider-specific branch.
- Public wire configurations expose the operations needed by independent adapters.
  The former mixed `ModelHTTPConfig` remains internal to the aggregate. Cross-package
  parsing/preparation helpers needed by existing hosts are public; module moves
  therefore increase the public graph. Application code should use factories,
  while adapter authors must treat these helper signatures as versioned API once
  released. No hidden cross-repository source inclusion is used.
- Shared batch-line iteration, upload metadata, decision/evaluation wrappers,
  URL construction and streaming tool-call buffering now live in lower core modules.
  Provider authentication, model catalogs and special error interpretation stay
  with provider implementations or the legacy hosting adapters.
- Anthropic upload has its own file client and retains upload-only behavior,
  headers, cancellation and unsupported-operation errors. OpenAI owns management
  of provider files. The generic multipart adapter is retained for existing
  compatible hosts through the legacy bridge.
- Image input/mask capability witnesses live in the module that defines the image
  class; provider hooks supply the catalog policy. A cross-module extension cannot
  substitute a witness that was already selected in the defining module.

Re-exports still use `@_exported import`, as in M2. This underscored compatibility
mechanism and normalized symbol comparison do not constitute a binary ABI promise.

## Tests and provenance

56 existing test files moved with their behavior: 19 Anthropic, 35 OpenAI and two
compatible. [test-relocation.json](test-relocation.json) records original/current
paths and hashes, and verifies that ordered test-function names are retained.
Shared recording/fixture transports and realtime helpers are test-only copies.
OpenAI owns its copied Responses resources; mixed provider and legacy integration
tests remain in the root. No previous test is replaced by a weaker placeholder.

All 3545 reported tests are retained: 3543 pre-migration tests plus the two M2
normal-import legacy consumer tests. Counts include 33 explicitly skipped live
provider checks. Test relocation metadata is not itself behavioral proof; the
full independent and aggregate suites supply that proof.

Existing per-package porting maps own every source, test and resource. Source
splits do not turn coarse upstream associations into verified parity. Upstream
provider factories and their tests were inspected at the inventory ref
`682e2dd71456f14f9da33a1b983d1998c3a1184c`; this is an inventory snapshot, not a
new assertion that the ref matches each published npm archive. No reviewed npm
version, capability row or provenance disposition was upgraded by extraction.
See [runtime-inventory.json](runtime-inventory.json) for the 362 current runtime
file hashes.

## Verification

All checks are local Apple Swift 6.4 on macOS arm64 unless stated otherwise.
Detailed commands, results and log hashes are in [verification.json](verification.json).

| Check | Result |
| --- | --- |
| Independent package suites | Core 126, Anthropic 135, compatible 7, OpenAI 270; zero failures |
| Compatibility aggregate | 3007 tests, 64 suites; zero failures; 33 live skips |
| Focused provider/host checks | Anthropic 131, OpenAI 266, compatible 7, aggregate MiniMax/Gateway/consumer 105; zero failures |
| External ordinary-import clients | AnthropicOnly, OpenAICompatibleOnly, OpenAIOnly and MixedProviders run with only their declared package closure copied outside the checkout |
| Core/legacy examples | Isolated CoreOnly passes; 19 existing executables build; offline OAuth marker passes |
| Public symbol preservation | All 6762 M0 public records match 7407 current graph records after module normalization; zero unmatched records |
| iOS compilation | Anthropic and OpenAI dependency closures compile for `arm64-apple-ios15.0-simulator` against installed iPhoneSimulator 27.1 SDK |
| Catalog/tooling | 52 packages, four extracted; deterministic generation; 9 tests pass, including unchanged upstream/capability import and invalid test dependency/resource rejection |
| Documentation | Clean dependency installation; zero vulnerabilities; check has zero errors/warnings/hints; production build has 98 pages |

The public API audit used fresh minimum-internal symbol graphs in every runtime
package, including synthesized/inherited public records, then demangled and
normalized module names. [api-comparison.json](api-comparison.json) records the
result. Documentation generation uses different extraction flags and replaces
those temporary graphs; reproduce the audit by dumping the minimum-internal
graphs again before running `Scripts/compare-migration-api.py`.

### Independent versions

`Scripts/verify-provider-versions.mjs` creates disposable local Git repositories
from the actual extracted sources and rendered distribution manifests. It verifies:

1. Anthropic **1.1.0** and OpenAI **1.3.0** resolve together against core **1.1.0**
   and compatible **1.0.0**, then the mixed ordinary-import client builds/runs.
2. Updating only the OpenAI requirement to **1.4.0** retains Anthropic **1.1.0**
   and the mixed client still builds/runs.
3. The declared core lower bound **1.0.0** resolves and builds/runs explicitly.
4. Anthropic **2.0.0**, requiring core 2.x, conflicts with OpenAI **1.3.0**,
   requiring core 1.x. The client allows either core major, so rejection comes
   from the two providers' requirements rather than a restrictive client pin.

These versions are **synthetic fixture tags on the same source snapshot**. They
prove SwiftPM package identities, constraint behavior and the exported dependency
shape, not compatibility across historical releases. They are not proposed
public version announcements. No external repository is written or required.

### Ongoing checks

`node Scripts/test-packages.mjs` runs all extracted packages in dependency order,
then the aggregate. Testing the root alone is insufficient because SwiftPM does
not execute dependency-package tests. Catalog-driven `testDependencies` and
`testResources` make those independent targets reproducible.

CI now includes that wrapper, provider/core isolation and version fixtures, plus
existing examples, tooling and documentation checks. These are configured checks;
this uncommitted source tree has no fresh hosted result. Actions artifact policy
is unchanged: documentation deployment handoff on main only, one-day retention.

## Limits and M4 handoff

- Canonical manifests intentionally use local paths. Do not publish this root
  package state. Deterministic distribution exports, release-set records,
  dependency-ordered release dry runs and resume checks belong to M4.
- Minimum tools/deployment declarations remain Swift 6.3, macOS 12 and iOS 15.
  There is no new hosted Swift 6.3.3 result, iOS runtime test, device proof or
  paid/live provider result. Simulator-target compilation is recorded separately.
- M0–M2 historical receipts are unchanged. Existing released tags and installation
  URLs are unchanged. No canonical commit, push, tag, organization creation,
  repository transfer or publication occurred. Local fixture commits/tags are
  disposable verification data only.
- M4 should preserve the package identity and source/test boundaries established
  here, export only catalog-owned inputs, render remote manifests, carry upstream
  evidence/dispositions and test clean clients from generated distributions.
  This stage does not begin M4 publication tooling.
