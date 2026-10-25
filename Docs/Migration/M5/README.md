# M5: organization and initial modular releases

Status: **in progress**. Started 2026-10-25. M6 has not started.

The `SwiftAISDK` organization has been created on GitHub Free (organization ID
347859412), with `ozio` as an active owner. The current canonical repository is
still `ozio/SwiftAISDK` (repository ID 1254813083); its transfer and modular releases
remain pending. The reviewed destination names are core, Anthropic, compatible
and OpenAI from the catalog. Do not create a new `SwiftAISDK/SwiftAISDK` repository
before transferring the existing repository.

Before-transfer inventory records 67 tag refs and 24 GitHub Releases, the current
main/base `fc4e5dc5116435d995c71ef36062662b38c42181`, Actions-based Pages deployment,
one environment, no repository webhook or deploy key, no Actions secret/variable,
and no branch protection/ruleset. Secrets were not retrieved. GitHub connector
scope did not expose organization membership; authenticated GitHub CLI readback
confirmed organization ownership and repository administration.

M0–M4 changes are ready for committed-source verification. The current canonical
root still uses local package paths and will not receive a new public release tag.
CI is pinned to Xcode 26.6 and explicitly checks Swift 6.3.3 before running all
extracted/aggregate suites. Native release readiness requires that fresh hosted
result; prior M0–M4 receipts are not substituted for it.

Remaining acceptance gates:

- Hosted Swift 6.3.3 and documentation verification on the committed migration.
- Review retained pilot upstream provenance and public adapter contract.
- Preserve old Git/tag access and provide documentation continuity during transfer.
- Publish allowlisted package exports in dependency order with immutable annotated
  tags, exact remote/ref/Release readback and resumable state.
- Resolve clean clients against the actual public tags, then record the immutable
  published set and update installation guidance.

Local preparation and intermediate validation do not mark M5 complete.
