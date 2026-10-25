# Package catalog and porting metadata

`packages.json` owns package identities, module/product names, proposed dependency
ranges, provider capability rows, and guide ownership. `upstream-lock.json` owns
reviewed npm versions and provenance. Update these inputs instead of editing
generated Swift capability rows or version tables.

Each `Packages/<identity>/Porting/map.json` owns upstream implementation/test paths
and current Swift source/test/resource paths. `workspace-map.json` retains the
legacy aggregate, mixed integration tests, test support, and examples. Imported
maps are coarse candidate relationships, not assertions that every listed
upstream test has been ported. Refine them during extraction while preserving
existing dispositions and known gaps.

The root remains the compatibility aggregate. Of 52 catalog packages, four are
`extracted`: core, Anthropic, OpenAI-compatible and OpenAI. They have sources,
tests and working local manifests; the other 48 are planned. Dependency ranges
are proposed release constraints. No organization, distribution repository or
modular release exists yet. Do not switch consumers to those URLs.

## Commands

```sh
node Scripts/sdk.mjs catalog validate
node Scripts/sdk.mjs generate
node Scripts/sdk.mjs generate --check
node --test Scripts/tests/*.test.cjs
```

Generation is offline and deterministic. It writes canonical package manifests,
the compiled capability descriptor, the Markdown capability table and version
rows, the package index, CI selection data, export input lists, and development
workspace identity data. `Porting/Generated/files.json` records its outputs;
`--check` reports drift without rewriting files. Narrative docs remain authored
in place; only the version table/snapshot span is replaced. Capability rendering
templates contain shared presentation logic, not provider registrations.

The JSON Schema definitions in `schemas/catalog.schema.json` are checked by a
small dependency-free validator supporting precisely the keywords used there:
`$ref`, `type`, `enum`, `pattern`, `properties`, `required`, `additionalProperties`
and `items`. Domain validation additionally checks identities, dependency cycles,
upstream ownership, paths, missing files, duplicate factories, capability names,
and source/test/resource coverage. Existing paths must remain inside the checkout.

The existing commands retain their flags and now read the catalog directly:

```sh
Scripts/check-upstream-versions.js --all
Scripts/check-upstream-versions.js --discover-packages --discover-kind provider,adapter,core
Scripts/update-upstream-test-inventory.js

node Scripts/sdk.mjs upstream check --all
node Scripts/sdk.mjs upstream prepare --package @ai-sdk/openai
```

The SDK upstream commands delegate to the existing version/diff implementation;
they do not yet add immutable archive preparation or release-matched test fetching.
A lookup never advances a reviewed baseline. Registered scaffolds are reported as
`tracked-unreviewed` during discovery and omitted from reviewed-version comparison.
Network failures remain explicit errors in version rows, including nonzero exit
with `--fail-on-outdated`.

## Add a selected provider

```sh
node Scripts/sdk.mjs package add --upstream @ai-sdk/example --module SwiftAIExample
```

Use this only for a provider selected for implementation. One command registers
the package and pending upstream entry; creates its source/test directories,
mapping, and usage-guide starting point; and regenerates all derived metadata.
No npm lookup or behavior port occurs. The scaffold has no capability rows, no
reviewed version, and no release readiness. Placeholder Swift files contain no
public API or assertions. Replace them with reviewed behavior and translated
upstream tests before changing implementation state.

The optional `--root <checkout>` runs any command against a separate checkout.
The tooling tests use disposable copies to exercise this flow, including stale
output, missing ownership, duplicate identities, unsafe paths, cycles, and a
scaffold incorrectly advertising support. The fixture provider is not registered
in the real repository.

## Verification selection and release boundary

```sh
node Scripts/sdk.mjs verify --affected --files Packages/swift-ai-openai/Sources/SwiftAIOpenAI/OpenAIResponsesModel.swift
```

This command selects packages; its JSON explicitly says `selection-only`. It does
not execute Swift tests. It includes downstream dependencies and widens unknown
or coarse mappings to all packages. During the aggregate phase, the required
current check is `node Scripts/test-packages.mjs`: extracted packages in dependency
order, then the aggregate. `--list` prints that command plan. CI also runs normal
external core/provider clients and synthetic Git version-resolution fixtures,
plus tooling and documentation checks.

The generated CI matrix is input for later package jobs. Planned/scaffold entries
have no independent build command. Export metadata is a file plan, not an export
or a release approval. Development workspace data records matching local and
remote identities. Extracted manifests use local path dependencies. The same
renderer can emit distribution ranges for disposable Git fixtures; independent
provider upgrades and incompatible core majors are tested outside the monorepo.
M4 adds deterministic export and local publication rehearsal from these same
identities; actual remote publication remains M5. See `Releases/README.md`.

## Imported provenance

The 54 reviewed version entries retain their existing values. The prior archive
inventory supplied integrity strings for 52 of them; `@ai-sdk/lmnt@3.0.36` and
`@ai-sdk/vercel@3.0.30` have explicit null integrity. No hash was invented or
silently fetched from a newer version.

Imported test refs point to the pinned upstream test-inventory snapshot and are
marked `inventory-snapshot-not-release-verified`. Contract families remain
unimported until the relevant declarations are reviewed. Upgrading an entry to
`reviewed` requires archive integrity, a matching release test ref, and recorded
contract families; metadata validation is still not runtime parity proof.

The migration-only baseline comparison is:

```sh
M1_VERIFY_IMPORT=1 node --test Scripts/tests/*.test.cjs
```

It compares against the frozen M1 import record and is deliberately excluded from
normal CI after future legitimate upstream updates. Do not rewrite that record
to make a new port pass. Normal CI checks the current catalog and generated
outputs. The original M0 artifacts likewise remain a historical snapshot.

## M2 core extraction

`swift-ai-core` is now an extracted local package with four runtime modules and
four test targets. The root package consumes its products with a relative SwiftPM
path dependency. Planned provider manifests remain unpublished and unbuildable
until their source extraction; their proposed `1.0.0` ranges are not releases.
Run all package suites through `node Scripts/test-packages.mjs`.

The generator derives the compatibility `AI` and `AIProviders` methods and the
`AICustomProvider` forwarding adapter from core Swift signatures. The development
parser uses SwiftSyntax/SwiftParser shipped with the active Xcode toolchain;
consumers have no parser dependency. Unsupported public declarations fail
generation rather than disappearing silently. macOS/Xcode is required to run
this generation command. Ordinary consumers compile the checked-in Swift files.

Core aliases resolve only through explicit resolvers. The legacy adapter injects
its existing default-provider/Gateway lookup lazily, including `AIDefaultProvider.withProvider` scopes. No provider implementation is linked into
core. The four short legacy global `customProvider` overloads remain in the
aggregate so importing its re-exported core does not create ambiguous functions.

## M3 provider pilot

Anthropic and the generic compatible layer depend only on lower core products.
OpenAI also depends on the compatible package for shared chat/completion,
embedding and image wire implementations. OpenAI-specific model policy, Responses,
audio, Live, files and skills remain in OpenAI. Anthropic hosting adapters and
other concrete provider policies remain in the aggregate and inject hooks.

Provider settings, factories and runtime tests are owned by their package. A test
may depend on the `SwiftAI` orchestration product without adding it to the runtime
target; module `testDependencies` records that distinction. `testResources` paths
are relative to `Tests/<Module>Tests` and must exist within the checkout.

`verify-provider-isolation.mjs` copies only each provider's dependency closure and
its ordinary-import consumer to a temporary directory. `verify-provider-versions.mjs`
uses local Git repositories and synthetic tags; it makes no claim about historical
release compatibility. Both delete their temporary files. Source/test moves and
all verification receipts are in `Docs/Migration/M3`.

## M4 deterministic export

Release planning reads reviewed `Releases/changes` entries and immutable released
sets. It selects version bumps independently of downstream test selection. Export
roots come from the same generator that writes `Generated/exports.json`; expansion
produces an explicit file/hash list for each candidate. Runtime and test bytes
are copied unchanged; public manifests, provenance, changelogs and standalone CI
are rendered. Relative canonical map references are preserved separately from
standalone paths so integration evidence remains traceable without copying siblings.

Use `node Scripts/sdk.mjs release plan`, `release export --dry-run` and
`release rehearse` as described in `Releases/README.md`. The complete gate is
`node Scripts/verify-release-rehearsal.mjs`. Local SwiftPM mirrors preserve the
remote distribution manifests during verification. No generated repository or
published release is implied by `state: extracted` or a successful dry run.
