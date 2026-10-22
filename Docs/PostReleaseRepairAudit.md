# Post-release repair audit — 2026-10-23

This pass repairs issues identified after SwiftAISDK 2.6.0. Published npm
baselines and model-provider coverage remain unchanged. New sandbox/bash tools,
UI step APIs and additional provider adapters are outside this repair.

## Changes and upstream references

| Area | Reference version | Implementation | Focused evidence |
| --- | --- | --- | --- |
| Protected downloads | `@ai-sdk/provider-utils` 5.0.65 | Translate `createSafeLookup` and validated redirects to native numeric Network.framework connections. Check every DNS answer, preserve original-host TLS trust, redirect credential isolation, limits and cancellation. Add fail-closed custom transport hooks. | `HTTPDNSPinningTests`, existing download/redirect/media/batch regressions |
| Streaming byte adapter | Native transport supporting `ai` 7.0.148 | Replace eager one-byte Data production with consumer-driven iteration. Release sources on completion, cancellation, overflow and destruction. Drop delivered results from DNS/socket callback boxes. | `HTTPStreamingBackpressureTests`, offline RSS probe |
| MCP OAuth migration | `@ai-sdk/mcp` 2.0.81 | Existing binding runtime already matches upstream. Add an executable offline example and secret/custom-auth regressions, including invalid-grant retries with issuer changes. | `MCPOAuthMigrationTests`, `MCPOAuthMigration` executable |
| OpenAI CI fixture | `@ai-sdk/openai` 4.0.99 | Split the nested source-URL assertion into typed intermediates to avoid the supported compiler's type-checking timeout. Preserve the comparison. | OpenAI Responses streaming/search regressions |
| Docs dependencies | Private npm package | Upgrade compatible Astro/Starlight/Sharp/checking dependencies, preserve remark processing, and require npm audit and Astro check in CI. | Clean install, full audit, Astro check/build, browser verification |

All reference versions above are unchanged from 2.6.0. The full old/latest
package table remains in [UpstreamPackageDiffAudit.md](UpstreamPackageDiffAudit.md)
and [ProviderVersionLedger.md](ProviderVersionLedger.md). Upstream fixture
references use `vercel/ai` commit `5893e994f9d8ac705811d3caec3e8faf2cd281ce`,
recorded in [UpstreamTestInventory.md](UpstreamTestInventory.md).

## Download security and migration

The default transport resolves once per hop, rejects mixed public/private
answer sets, and connects only to validated numeric addresses. HTTPS checks the
certificate against the original hostname. Resolver work is limited to four
concurrent system lookups; cancelled or timed-out results cannot start a later
connection. Callback boxes drop delivered values even if an operating-system
callback remains alive.

The protected path supports HTTP/1.1 identity-encoded GET responses with bounded
headers, trailers and body size, including fixed-length, chunked and
connection-close bodies. Ambiguous framing fails explicitly. Ordinary provider
API requests continue through URLSession. DNS/TLS tests use local sockets and
an in-memory certificate chain without changing the user's keychain.

`AITransport.sendValidatedDownload(_:)` and
`AIStreamingTransport.streamValidatedDownload(_:)` have default implementations,
so existing conformers still compile. Custom transports must implement
equivalent connection protection to download untrusted URLs. An injected
custom URLSession now rejects those downloads; use the default transport or
provide protected hooks. Exact configured `trustedOrigin` exemptions remain.
See [DownloadSecurity.md](DownloadSecurity.md) for proxy, session, authentication
delegate, framing and local-endpoint compatibility details.

MCP OAuth still requires a trusted issuer or stored authorization-server binding
for pre-registered secrets. Custom token authentication must explicitly set
`usesCustomClientAuthentication = true`. The offline example demonstrates
binding, callback validation, PKCE/state persistence and token exchange with
dummy credentials. It is not a JWT signer or a live authorization-server test.

The additive public transport hooks require a **minor** release under the
repository's SemVer rule. No public API is removed or deprecated. Stricter
custom-transport download behavior is an intentional security change. The
canonical version remains the SwiftPM git tag; private docs package and default
MCP client identity versions are unchanged.

## Streaming memory measurement

`python3 Scripts/measure-http-streaming-memory.py --runs 3` builds a probe in a
temporary directory and runs each sample in a fresh process. A local URLProtocol
supplies a 1 MiB response; the body stays unread for two seconds, then the probe
checks a 128-byte prefix and cancels. Baseline sources came from tag 2.6.0,
using the same machine, Swift 6.4 toolchain and probe.

| Snapshot | Resident-memory growth, three runs | Median |
| --- | --- | --- |
| 2.6.0 eager adapter | 55,001,088; 55,050,240; 54,558,720 bytes | 52.5 MiB |
| Demand-driven adapter | 2,785,280; 2,703,360; 2,670,592 bytes | 2.6 MiB |

This measures the HTTP byte-to-Data bridge for this workload, not a whole-facade
constant-memory guarantee. URLSession buffers, parser state, accumulated result
getters and tool-loop history remain separate; per-byte conversion remains.
Regressions directly check unread/slow consumers, byte fidelity, limits,
reason-preserving abort and cancellation of an actually suspended source read.

## Documentation and live verification

The complete docs npm graph now audits with **zero vulnerabilities**, down from
19 (1 critical, 16 high, 1 moderate, 1 low). Exact versions and Node/browser
requirements are in [DocumentationDependencies.md](DocumentationDependencies.md).
A build with the GitHub Pages base path was inspected in Zen: Files and MCP
pages rendered, search returned the OAuth pages, its result opened correctly,
and the migration content had no horizontal overflow. Temporary preview
resources were closed afterward.

All 33 live-provider tests now use an explicit Swift Testing opt-in trait
instead of silently returning as successful tests. The representative runner
selects short, no-retry OpenAI streaming, Anthropic generation and Google
streaming requests. Plan mode and missing-opt-in/missing-credential failure
paths were exercised without API calls. `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`
and `GEMINI_API_KEY` were absent. Live provider acceptance is **unverified**;
no paid requests were made.

## Final local verification

| Command | Result |
| --- | --- |
| `swift test --filter 'HTTPDNSPinning\|HTTPStreamingBackpressure\|MCPOAuthMigration\|WeeklyCoreMCP20260927'` | 40 tests in 4 suites passed; includes both callback-result completion orders |
| `swift test --filter MCPOAuthMigration` | 4 tests / 7 parameter cases passed independently |
| `swift test --filter HTTPDNSPinning` | Independently reverified after the final lifetime regression change |
| `swift test` | 3,459 tests in 55 suites: 3,426 passed, 33 opt-in live tests skipped, zero issues; Swift 6.4 |
| `swift build --package-path Examples` | All 18 executable targets build |
| `swift run --package-path Examples MCPOAuthMigration` | Both offline flows verified; `MCP_OAUTH_MIGRATION_OFFLINE_OK` |
| `npm ci --prefix docs-site` | Clean install succeeded |
| `npm audit --prefix docs-site` | Zero vulnerabilities, including development dependencies |
| `npm --prefix docs-site run check` | 4 Astro files, zero errors/warnings/hints |
| `npm --prefix docs-site run build` | 97 pages; Pagefind index and sitemap generated |
| `git diff --check` | Passed |

The static build emits Starlight's optional missing-i18n/custom-404 notices;
its default English 404 page is generated. npm reports an unapproved optional
fsevents install script; no global script-approval setting was changed and the
clean build succeeds. These notices are separate from the zero audit findings
and zero Astro check diagnostics. Hosted compiler/deployment results are
recorded in the GitHub Release once its exact-commit workflow completes.

## Remaining scope

Fresh registry/search and exact-prefix discovery still finds 91 scoped package
names and no new model-provider names. `@ai-sdk/tool-bash` is separate sandbox
tooling and remains unported: its last source-reviewed version was 1.0.0; the
fresh registry metadata now reports 1.0.3. The JS `experimental_streamTextLowMemory` facade contract, UI wire
and step surfaces, provider-specific realtime/transcription/batch/codec gaps,
and browser/framework/workflow adapters remain in
[PortingStatus.md](PortingStatus.md). DNS connection pinning is now implemented
and is no longer an active gap.

## Registry readback during the repair

The final registry readback queried all 54 tracked packages with no registry
errors. While this follow-up was in progress, 52 new patch versions appeared.
This repair retains the reviewed 2.6.0 baselines; it does **not** claim parity
with that newer publication wave. Its source/API/test audit belongs to the next
upstream port pass, separate from the requested CI, security, migration and
streaming repairs. LMNT 3.0.36 and Vercel 3.0.30 remain unchanged.

| Package | Retained reference | Registry latest | Disposition |
| --- | --- | --- | --- |
| `@ai-sdk/alibaba` | 2.0.73 | 2.0.74 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/amazon-bedrock` | 5.0.121 | 5.0.122 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/anthropic` | 4.0.85 | 4.0.86 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/anthropic-aws` | 2.0.78 | 2.0.79 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/assemblyai` | 3.0.65 | 3.0.66 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/azure` | 4.0.107 | 4.0.108 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/baseten` | 2.1.53 | 2.1.54 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/black-forest-labs` | 2.0.67 | 2.0.68 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/bytedance` | 2.0.68 | 2.0.69 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/cartesia` | 3.0.60 | 3.0.61 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/cerebras` | 3.0.75 | 3.0.76 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/cohere` | 4.0.66 | 4.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/deepgram` | 3.1.36 | 3.1.37 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/deepinfra` | 3.0.75 | 3.0.76 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/deepseek` | 3.0.70 | 3.0.71 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/elevenlabs` | 3.0.66 | 3.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/fal` | 3.0.66 | 3.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/fish-audio` | 3.0.43 | 3.0.44 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/fireworks` | 3.0.78 | 3.0.79 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/gateway` | 4.0.121 | 4.0.122 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/gmicloud` | 3.0.46 | 3.0.47 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/gladia` | 3.0.65 | 3.0.66 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/google` | 4.0.102 | 4.0.103 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/google-vertex` | 5.0.119 | 5.0.120 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/groq` | 4.0.67 | 4.0.68 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/heygen` | 3.0.7 | 3.0.8 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/huggingface` | 2.0.75 | 2.0.76 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/hume` | 3.0.65 | 3.0.66 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/klingai` | 4.0.67 | 4.0.68 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/luma` | 3.0.66 | 3.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/mcp` | 2.0.81 | 2.0.82 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/minimax` | 3.0.62 | 3.0.63 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/mistral` | 4.0.69 | 4.0.70 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/moonshotai` | 3.0.74 | 3.0.75 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/open-responses` | 2.0.70 | 2.0.71 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/openai` | 4.0.99 | 4.0.100 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/openai-compatible` | 3.0.75 | 3.0.76 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/perplexity` | 5.0.17 | 5.0.18 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/prodia` | 2.0.66 | 2.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/quiverai` | 2.0.66 | 2.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/replicate` | 3.0.66 | 3.0.67 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/revai` | 3.0.65 | 3.0.66 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/togetherai` | 3.0.76 | 3.0.77 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/topaz` | 3.0.12 | 3.0.13 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/typesafe-ai` | 3.0.24 | 3.0.25 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/voyage` | 2.0.65 | 2.0.66 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/xai` | 5.0.27 | 5.0.28 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/zai` | 3.0.37 | 3.0.38 | Next upstream audit; no baseline bump in this repair |
| `ai` | 7.0.148 | 7.0.149 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/provider` | 4.0.31 | 4.0.32 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/provider-utils` | 5.0.65 | 5.0.66 | Next upstream audit; no baseline bump in this repair |
| `@ai-sdk/react` | 4.0.152 | 4.0.153 | Next upstream audit; no baseline bump in this repair |
