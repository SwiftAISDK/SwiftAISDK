# Weekly upstream audit, 2026-11-22

Canonical source base `de7b5455a44296a8bcdefadf635981b93efc6bf1` on `main`.

The registry prefix and npm search yielded 98 published packages including `ai`.
The repository mentioned four additional names that returned 404 and were confirmed
as examples or test fixtures. Of 57 tracked packages, 55 changed and two matched
the local review. Liquid was found through the registry prefix.

Verified 112 tracked and Liquid archives
against their npm SHA-512 and independent SHA-256, and verified 1,759
test file snapshots at immutable refs whose package manifests match the release.
The tracked packages have 56 changed test files.
Liquid's initial port covers three additional matching-release files.
The separate scope review verified 70 archives for the remaining packages.

The [structured audit](WeeklyUpstreamAudit20261122.json) includes each archive
hash, release ref, source/test file disposition, mapped Swift test file and retained
gap. Identical older tests without a case-level mapping are marked as unverified
historical coverage. The [previous parity audit](UpstreamParityAudit20261116.md)
documents the earlier gaps.

## Reviewed npm packages

| Package | Prior | Latest | Changed tests | Disposition |
| --- | --- | --- | ---: | --- |
| `@ai-sdk/alibaba` | `2.0.91` | `2.0.93` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/amazon-bedrock` | `5.0.142` | `5.0.146` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/anthropic` | `4.0.105` | `4.0.107` | 0 | Align request identity. The changed bash tool output typing is specific to the JavaScript sandbox. |
| `@ai-sdk/anthropic-aws` | `2.0.98` | `2.0.100` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/assemblyai` | `3.0.82` | `3.0.85` | 3 | Add buffered Speech V4 with a separate TTS host, typed encoding and usage, and update Transcription V4 to AssemblyAI STT 3.7. |
| `@ai-sdk/azure` | `4.0.126` | `4.0.130` | 2 | Route MAI-Image-2.7 and MAI-Image-2.7-Flash and send supported background settings on generation and edit requests. |
| `@ai-sdk/baseten` | `2.1.71` | `2.1.73` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/black-forest-labs` | `2.0.85` | `2.0.87` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/bytedance` | `2.0.86` | `2.0.88` | 0 | Review dependency/manifest drift and upstream bundle identity. The native ByteDance requests do not advertise that npm identity. |
| `@ai-sdk/cartesia` | `3.0.76` | `3.0.78` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/cerebras` | `3.0.93` | `3.0.95` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/cohere` | `4.0.84` | `4.0.86` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/deepgram` | `3.1.53` | `3.1.55` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/deepinfra` | `3.0.93` | `3.0.95` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/deepseek` | `3.0.87` | `3.0.89` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/elevenlabs` | `3.0.86` | `3.0.88` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/fal` | `3.0.84` | `3.0.86` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/fireworks` | `3.0.96` | `3.0.98` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/fish-audio` | `3.0.59` | `3.0.61` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/gateway` | `4.0.146` | `4.0.152` | 7 | Add Extraction V4, continuous Gateway Realtime Live and structured access-policy errors. |
| `@ai-sdk/gladia` | `3.0.82` | `3.0.84` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/gmicloud` | `3.0.64` | `3.0.66` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/google` | `4.0.121` | `4.0.124` | 6 | Add Interactions MCP server tool, scoped header redaction, Neon reasoning, prompt blocking errors and compatible Batch output validation. |
| `@ai-sdk/google-vertex` | `5.0.141` | `5.0.144` | 1 | Add Gemini Live remote VAD settings and single-turn completion, and expose the shared Interactions MCP server tool. |
| `@ai-sdk/groq` | `4.0.84` | `4.0.86` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/heygen` | `3.0.25` | `3.0.27` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/huggingface` | `2.0.93` | `2.0.95` | 0 | Review dependency/manifest drift and upstream bundle identity. The native Hugging Face adapter retains its Swift request identity. |
| `@ai-sdk/hume` | `3.0.81` | `3.0.83` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/klingai` | `4.0.85` | `4.0.87` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/liquid` | Initial port | `3.0.1` | 3 initial | Initial Liquid Decision V4 port with typed decisions, multimodal evidence, complete cost/usage and release-matched fixtures. |
| `@ai-sdk/lmnt` | `3.0.36` | `3.0.36` | 0 | Latest npm version equals the existing review. No new Swift change selected. |
| `@ai-sdk/luma` | `3.0.84` | `3.0.86` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/mcp` | `2.0.99` | `2.0.102` | 2 | Report POST event streams ending before a matching JSON-RPC response as native MCP errors. |
| `@ai-sdk/minimax` | `3.0.82` | `3.0.84` | 0 | Review derived TypeScript image IDs and policy lookup. The existing native String model ID and request options still apply. |
| `@ai-sdk/mistral` | `4.0.87` | `4.0.89` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/moonshotai` | `3.0.93` | `3.0.95` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/open-responses` | `2.0.87` | `2.0.89` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/openai` | `4.0.118` | `4.0.122` | 6 | Resolve historical additional tools with currently registered declarations and expose input transformations across unary, stream and Batch results. |
| `@ai-sdk/openai-compatible` | `3.0.92` | `3.0.94` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/parallel` | `3.0.9` | `3.0.11` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/perplexity` | `5.0.35` | `5.0.37` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/prodia` | `2.0.84` | `2.0.86` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/provider` | `4.0.38` | `4.0.39` | 0 | Review the extraction model discriminator in the TypeScript NoSuchModelError. Swift uses the existing typed .extraction capability. |
| `@ai-sdk/provider-utils` | `5.0.81` | `5.0.83` | 5 | Keep empty extraction values at the model boundary. JS Standard Schema and sandbox helper changes have no standalone Swift product. |
| `@ai-sdk/quiverai` | `2.0.83` | `2.0.85` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/react` | `4.0.177` | `4.0.183` | 1 | Review direct minted-token continuous Live support. Native coverage uses Gateway WebSocket rather than the React hook. |
| `@ai-sdk/replicate` | `3.0.84` | `3.0.86` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/revai` | `3.0.81` | `3.0.83` | 0 | Review catalog-derived model IDs and internal declarations, preserve the native String model API and update request identity. |
| `@ai-sdk/scaledown` | `3.0.1` | `3.0.3` | 1 | Keep empty extraction lists in the model response and normalize them in the Core facade. |
| `@ai-sdk/tencent` | `3.0.3` | `3.0.5` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/togetherai` | `3.0.94` | `3.0.96` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/topaz` | `3.0.28` | `3.0.30` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/typesafe-ai` | `3.0.40` | `3.0.42` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/vercel` | `3.0.30` | `3.0.30` | 0 | Latest npm version equals the existing review. No new Swift change selected. |
| `@ai-sdk/voyage` | `2.0.83` | `2.0.85` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `@ai-sdk/xai` | `5.0.46` | `5.0.48` | 0 | Review catalog-derived model IDs and modality declarations, preserve String IDs and update request identity. |
| `@ai-sdk/zai` | `3.0.55` | `3.0.57` | 0 | Align the native versioned request identity after reviewing package source, API declarations and exact release tests. |
| `ai` | `7.0.173` | `7.0.179` | 22 | Port pre-output steering and unsigned automatic approval denials, typed Batch output, extraction aliases and lifecycle, telemetry privacy, and deep native UI metadata validation. |

## New provider and components

- Liquid Decision V4 supports d1.2 and d1.2-ultra with typed Choice, Boolean/noul and Box
  decisions, usage, cost and refusals. The test map records 37 portable expanded cases,
  two JS-only exclusions and two unchanged exact upstream fixtures.
  [Liquid test map](../../Packages/swift-ai-liquid/Porting/upstream-tests.json)
- AssemblyAI buffered speech uses its separate origin, typed audio format controls, binary output,
  and billable character metadata. The native AssemblyAI suite covers 49 translated matching-release
  cases across speech, transcription and error fixtures.
- Gateway Extraction V4 and Realtime Live include typed answers and access-policy errors, direct
  minted-token connections and native WebSocket framing. Current-release tests cover both protocol
  and provider dispatch.
- Google Interactions MCP server credentials are redacted in telemetry. Vertex Live transcription
  adds server VAD controls and single-turn completion.

## Coverage boundaries

- Standalone Google Developer API transcription and speech translation were already absent in the
  previous source review. The five changed Developer API transcription scenarios remain open
  for that endpoint. The corresponding live VAD and manual activity scenarios pass against
  the native Vertex implementation.
- Existing browser hooks, Node diagnostics channels, JavaScript sandbox and schema products stay
  outside the Swift runtime. Native analogues and representability limits are enumerated in the
  structured file. Historical gaps in the larger suites remain listed per file.
- Provider tests use injected transports and fixtures. Paid provider calls remain opt-in.

## Packages outside the native provider surface

| Package | Prior inspected | Latest | Disposition |
| --- | --- | --- | --- |
| `@ai-sdk/angular` | `3.0.173` | `3.0.179` | framework binding |
| `@ai-sdk/code-mode` | `1.0.130` | `1.0.136` | tooling or tool product |
| `@ai-sdk/codemod` | `4.0.4` | `4.0.4` | tooling or tool product |
| `@ai-sdk/devtools` | `1.0.76` | `1.0.82` | tooling or tool product |
| `@ai-sdk/durable-agent` | `0.0.1` | `0.0.1` | workflow agent product |
| `@ai-sdk/harness` | `1.0.184` | `1.0.190` | harness sandbox product |
| `@ai-sdk/harness-acp` | `1.0.124` | `1.0.130` | harness sandbox product |
| `@ai-sdk/harness-claude-code` | `1.0.188` | `1.0.194` | harness sandbox product |
| `@ai-sdk/harness-cline` | `1.0.112` | `1.0.118` | harness sandbox product |
| `@ai-sdk/harness-codex` | `1.0.186` | `1.0.192` | harness sandbox product |
| `@ai-sdk/harness-cursor` | `1.0.99` | `1.0.105` | harness sandbox product |
| `@ai-sdk/harness-deepagents` | `1.0.184` | `1.0.190` | harness sandbox product |
| `@ai-sdk/harness-fx` | `1.0.100` | `1.0.106` | harness sandbox product |
| `@ai-sdk/harness-github-copilot` | `1.0.81` | `1.0.87` | harness sandbox product |
| `@ai-sdk/harness-grok-build` | `1.0.123` | `1.0.129` | harness sandbox product |
| `@ai-sdk/harness-opencode` | `1.0.187` | `1.0.193` | harness sandbox product |
| `@ai-sdk/harness-pi` | `1.0.187` | `1.0.193` | harness sandbox product |
| `@ai-sdk/inception` | `0.0.0` | `0.0.0` | Implementation-free seed |
| `@ai-sdk/langchain` | `3.0.173` | `3.0.179` | js adapter |
| `@ai-sdk/llamaindex` | `3.0.173` | `3.0.179` | js adapter |
| `@ai-sdk/otel` | `1.0.173` | `1.0.179` | opentelemetry adapter |
| `@ai-sdk/policy-opa` | `1.0.173` | `1.0.179` | policy product |
| `@ai-sdk/rsc` | `3.0.173` | `3.0.179` | framework binding |
| `@ai-sdk/sandbox-just-bash` | `1.0.184` | `1.0.190` | harness sandbox product |
| `@ai-sdk/sandbox-vercel` | `1.0.184` | `1.0.190` | harness sandbox product |
| `@ai-sdk/solid` | `1.2.13` | `1.2.13` | framework binding |
| `@ai-sdk/spacexai` | `0.0.0` | `0.0.0` | Implementation-free seed |
| `@ai-sdk/specification` | `0.0.0` | `0.0.0` | Implementation-free seed |
| `@ai-sdk/svelte` | `5.0.173` | `5.0.179` | framework binding |
| `@ai-sdk/swarm` | `0.1.39` | `0.1.39` | workflow agent product |
| `@ai-sdk/test-server` | `2.0.4` | `2.0.4` | tooling or tool product |
| `@ai-sdk/tool-bash` | `1.0.27` | `1.0.33` | tooling or tool product |
| `@ai-sdk/tool-web-fetch` | `1.0.23` | `1.0.29` | tooling or tool product |
| `@ai-sdk/tools` | `0.0.0` | `0.0.0` | Implementation-free seed |
| `@ai-sdk/tui` | `1.0.174` | `1.0.180` | tooling or tool product |
| `@ai-sdk/ui-utils` | `1.2.11` | `1.2.11` | framework binding |
| `@ai-sdk/valibot` | `3.0.81` | `3.0.83` | schema adapter |
| `@ai-sdk/vue` | `4.0.173` | `4.0.179` | framework binding |
| `@ai-sdk/workflow` | `2.0.105` | `2.0.111` | workflow agent product |
| `@ai-sdk/workflow-harness` | `1.0.184` | `1.0.190` | workflow agent product |

## Swift release selection

The reviewed change selects 52 units (38 patch, 13 minor,
1 initial). The module versions and compatibility notes are in the
[release change](../../Releases/changes/weekly-upstream-20261122.json).

The MCP minimum is Core 1.3.0, where the tool title and metadata properties first
become available. Providers that use Core 1.6's public image-model conformance
require OpenAI Compatible 1.4.0. The structured audit records the exact evidence.

| Swift package | Prior | Candidate | Bump | Compatibility |
| --- | --- | --- | --- | --- |
| `swift-ai-alibaba` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-amazon-bedrock` | `1.2.0` | `1.3.0` | minor | Source-compatible request-header update. Requires SwiftAIOpenAICompatible 1.4.0 for the public image model conformance introduced in Core 1.6.0. |
| `swift-ai-anthropic` | `1.5.0` | `1.5.1` | patch | Source-compatible request-header update. |
| `swift-ai-anthropic-aws` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-assemblyai` | `1.2.0` | `1.3.0` | minor | Additive speech API and settings. The transcription adapter places every supplied model ID in the speech_models array. |
| `swift-ai-azure` | `1.3.0` | `1.4.0` | minor | Additive image options. The MAI route skips auto with a warning. |
| `swift-ai-baseten` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-black-forest-labs` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-cartesia` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-cerebras` | `1.3.0` | `1.4.0` | minor | Source-compatible request-header update. Requires SwiftAIOpenAICompatible 1.4.0 for the public image model conformance introduced in Core 1.6.0. |
| `swift-ai-cohere` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-core` | `1.6.0` | `1.7.0` | minor | Existing Swift overloads remain available. Use steering interrupts to retry the same logical step before output. Extraction facade results represent empty strings and lists as missing values. |
| `swift-ai-deepgram` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-deepinfra` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-deepseek` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-elevenlabs` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-fal` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-fireworks` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-fish-audio` | `1.1.2` | `1.1.3` | patch | Source-compatible request-header update. |
| `swift-ai-gateway` | `1.4.0` | `1.5.0` | minor | Additive factories and metadata. Requires SwiftAI Core 1.7.0 for source-compatible structured errors and correct retry handling. |
| `swift-ai-gladia` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-gmicloud` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-google` | `1.4.0` | `1.5.0` | minor | Use JSON mode or disable structured outputs for Google Batch requests that previously supplied a wire schema. Requires SwiftAI Core 1.7.0 for contextual credential redaction. |
| `swift-ai-google-vertex` | `1.3.0` | `1.4.0` | minor | Additive transcription options and tool API. Requires SwiftAIGoogle 1.5.0 for shared tool and telemetry behavior. Requires SwiftAIOpenAICompatible 1.4.0 for the public image model conformance introduced in Core 1.6.0. |
| `swift-ai-groq` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-heygen` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-hume` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-klingai` | `1.1.3` | `1.1.4` | patch | Source-compatible request-header update. |
| `swift-ai-liquid` | — | `1.0.0` | initial | Initial package release. API keys resolve at call time through LIQUID_API_KEY, explicit settings or an async credential supplier. |
| `swift-ai-luma` | `1.1.3` | `1.1.4` | patch | Source-compatible request-header update. |
| `swift-ai-mcp` | `1.3.0` | `1.4.0` | minor | Source-compatible error handling correction. Requires SwiftAI Core 1.3.0 for existing tool title and metadata. |
| `swift-ai-minimax` | `1.4.0` | `1.4.1` | patch | Source-compatible request-header update. |
| `swift-ai-mistral` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-moonshotai` | `1.2.0` | `1.3.0` | minor | Source-compatible request-header update. Requires SwiftAIOpenAICompatible 1.4.0 for the public image model conformance introduced in Core 1.6.0. |
| `swift-ai-open-responses` | `1.1.2` | `1.1.3` | patch | Source-compatible request-header update. |
| `swift-ai-openai` | `1.4.0` | `1.5.0` | minor | Register history-loaded tools again on each call using omitFromRequestTools. The adapter uses the current declaration when replaying a tool reference. Requires SwiftAIOpenAICompatible 1.4.0 for the public image model conformance introduced in Core 1.6.0. |
| `swift-ai-openai-compatible` | `1.4.0` | `1.4.1` | patch | Source-compatible request-header update. |
| `swift-ai-parallel` | `1.0.0` | `1.0.1` | patch | Source-compatible request-header update. |
| `swift-ai-perplexity` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-prodia` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-quiverai` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-replicate` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-revai` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-scaledown` | `1.0.0` | `1.1.0` | minor | Low-level extraction callers can distinguish an empty list from a missing field. Requires SwiftAI Core 1.7.0 for facade normalization. |
| `swift-ai-tencent` | `1.0.0` | `1.0.1` | patch | Source-compatible request-header update. |
| `swift-ai-togetherai` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-topaz` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-typesafe-ai` | `1.3.0` | `1.3.1` | patch | Source-compatible request-header update. |
| `swift-ai-ui` | `1.3.0` | `1.3.1` | patch | Source-compatible validation correction. Invalid nested metadata is reported at its first path. |
| `swift-ai-voyage` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |
| `swift-ai-xai` | `1.3.0` | `1.4.0` | minor | Source-compatible request-header update. Requires SwiftAIOpenAICompatible 1.4.0 for the public image model conformance introduced in Core 1.6.0. |
| `swift-ai-zai` | `1.2.0` | `1.2.1` | patch | Source-compatible request-header update. |

Canonical, published-ref, and public consumer verification are separate
release gates. Published package versions are indexed in
[Releases/sets](../../Releases/sets/).
