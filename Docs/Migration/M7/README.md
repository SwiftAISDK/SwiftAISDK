# M7 — modular umbrella and migration

Status: in progress. Previous stage: [M6](../M6/README.md).
Starting canonical commit: `9b2de4c61eca0df6c07e5756851df3fd7b33f820`.

This stage closes the existing migration plan. It does not select new upstream
providers, advance production npm baselines, or change provider behavior.

## Completion gates

1. Generate a remote-only 3.0 umbrella manifest and a separate local development
   workspace from the existing catalog. Preserve ordinary and module-qualified
   legacy imports, all existing tests/resources, and platform minimums.
2. Rehearse an upstream provider update with a changed test and shared-helper
   impact, plus a disposable provider registration. Verify owners, downstream
   selection, reviewed provenance, changed-unit-only releases, and rejection of
   incomplete work. No additional hard-coded package lists.
3. Complete deterministic exports, standalone tests and fresh dependency-bound
   clients locally. Publish only changed units (48 initial packages, core and
   Anthropic minor releases), preserving existing immutable releases.
4. Verify actual public Git tags without local mirrors, including minimal and
   complete clients, independently pinned provider versions, usage examples,
   the previous 2.x package and current release provenance. Publish the tested
   modular release set and consumer lockfile example.
5. Publish the 3.0 migration guide and annotated umbrella release after its
   dependencies are available. Update public installation docs, porting/release
   instructions and automation entry points together.
6. After the main work and local checks finish, restore CI in every affected
   repository and perform the final hosted verification and documentation
   deployment. Record remote refs, CI restoration and hosted page readback.

Automatic CI remains suspended until gate 6 under the user's explicit policy.
New distribution repositories must have Actions suspended before their first
publication. No public package tag is moved or replaced. Intermediate canonical
commits receive no root release tag.

Evidence is added here as each gate completes. A pending gate is not completion.

## Source preparation

- The public umbrella manifest uses remote compatible ranges. The catalog also
  generates the ignored local workspace through `sdk.mjs dev`; original source
  and test files are linked, not duplicated or rewritten.
- [Preservation](preservation.json): all 1039 pre-existing runtime, test and
  resource files are unchanged from M6, as are the npm baselines, capabilities,
  upstream inventory and published pilot record.
- [Maintenance rehearsal](maintenance-rehearsal.json): real OpenAI
  `4.0.101 → 4.0.102` archives and release-matched tests; provider failure, isolated
  shared-parser failure, then two passing translated tests. Only core/OpenAI
  receive synthetic local patch tags. A one-command scaffold creates generated
  registrations and cannot pass release review while unimplemented.
- The ordinary-import complete consumer compiles qualified legacy model/result,
  MCP and UI names and runs both explicit and scoped-default provider calls with
  an injected offline transport. Its `@Sendable` closure is explicit so the
  command-line entry point also compiles with Swift 6.4 actor isolation.
- Tooling checks: 23 passed, one historical M1 snapshot check explicitly skipped.
  Documentation: clean install, zero diagnostics, 99 pages built locally.

The committed-source local publication gate and public Git consumer verification
are still required. No M7 packages or umbrella tag are published at this checkpoint.
