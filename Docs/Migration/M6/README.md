# M6: remaining package extraction

Status: **in progress**. Started 2026-10-26 (Asia/Tokyo), from canonical
`20bebd6b0a8aef866b96c6eafc8c2ad406257292`. M7 has not started.

## Scope and acceptance

Extract the remaining provider families, independent media/audio adapters, MCP
and native UI. Preserve all existing capabilities, tests, fixtures and documented
upstream gaps. Keep the legacy import and factories through forwarding adapters;
remove concrete implementation ownership from the temporary aggregate only after
all packages have moved. No new provider or upstream baseline is selected here.

Completion requires all extracted package suites and the legacy integration suite,
public imports and offline consumers, distribution-tree verification, symbol and
test-preservation comparison, toolchain/platform checks, deterministic catalog and
export generation, documentation checks, and exact-commit hosted CI evidence.
The stage is not complete until those receipts are recorded.

## Work in progress

- Google runtime, files, image capabilities and four single-provider test files
  now belong to `swift-ai-google`. Its configuration contains Google-specific
  options and a neutral core HTTP client. The first full standalone run passed
  69 tests; final verification must use the finished M6 tree.
- Vertex runtime and focused suites now belong to `swift-ai-google-vertex`.
  Shared Gemini algorithms remain in Google through an explicit hosting API.
  Native MaaS/xAI/Anthropic factories compose the existing wire adapters. The
  first standalone full run passed 26 tests; mixed initializer assertions remain
  in the workspace.
- Core adds `AIProviderHTTPConfiguration`, a neutral forwarding protocol that
  preserves request construction, routing, streaming and adapter error policies.
  Its two focused transport tests passed. Consumers of this new API declare a
  future minimum core 1.1.0; that version is not yet published.
- Bedrock and Anthropic AWS now own their runtime. The shared SigV4 signer is in
  transport; AWS Files composes Anthropic's upload adapter through an additive
  namespace initializer. Standalone suites passed 49 and 9 tests, with 54 legacy
  integration checks. The additive Anthropic API requires future version 1.1.0.
- Cerebras, Cohere and Voyage now have small provider-specific settings and own
  their focused test suites (25, 23 and 10 tests). Root compatibility checks passed
  after each batch. Shared reranking parsing, HTTP audio error parsing and media
  request helpers moved to provider-neutral utilities without changing algorithms.
- Groq and Mistral standalone suites passed 28 and 32 tests; the mixed legacy
  checks passed 30 tests. Their wire adapters and conversation/speech routes stay
  provider-owned.
- Deepgram, Hume, LMNT and Perplexity standalone suites passed 20, 13, 13 and 17
  tests. A TypeSafeAI test found in the mixed Perplexity suite remains assigned to
  TypeSafeAI instead of introducing a provider dependency.
- DeepSeek and Alibaba standalone suites passed 41 and 32 tests. DeepSeek Files
  moved with its language adapter; Azure hosting will consume its explicit model
  configuration. Alibaba retains its existing language, embedding and video routes.
- AssemblyAI, Gladia and Rev.ai standalone suites passed 16, 15 and 13 tests.
  Their transcription parsers moved from the mixed root file into their packages.
- Cartesia and Fish Audio standalone suites passed 25 and 16 tests, including
  Cartesia's duplex transcription lifecycle. ElevenLabs passed 30 tests covering
  unary/streaming speech, transcription and its extended audio operations.
- The neutral `SpeechSocketSession` moved from Gateway's file to core utilities;
  Gateway and ElevenLabs retain their own framing, authentication and error rules.
  Provider-facing asynchronous video operation contracts moved from the core
  facade into `SwiftAIProvider`, preserving their declarations and facade exports.
- MiniMax's native configuration composes Anthropic's Messages adapter. Its
  standalone suite passed 40 tests, including the M3.1 hosting policy and video
  start/status behavior. The root adapter uses the same MiniMax policy function.
- TypeSafeAI, Hugging Face, GMI Cloud, Vercel and Z.AI standalone suites passed
  11, 13, 8, 5 and 15 tests. Legacy factory/initializer bridges preserve the old
  aggregate entry points; the compatible adapters remain shared.
- ByteDance, HeyGen and Topaz standalone suites passed 24, 38 and 34 tests.
  Black Forest Labs, Luma, Replicate and Fal passed 32, 16, 23 and 21 tests;
  their image-file/mask capability declarations moved with their implementations.
- Together AI and Moonshot passed 13 and 32 tests. Moonshot's conversion, usage,
  cache metadata and ordering policy is installed through a provider-owned hook.
  Baseten, DeepInfra and Fireworks passed 16, 13 and 14 tests; routing, error
  policies and polling remain provider-owned. A legacy integration checkpoint
  for this media/compatible batch passed 19 tests.
- KlingAI and Prodia passed 25 and 15 tests. KlingAI's settings and per-request
  JWT refresh moved together; legacy aggregate factories use its native config.
- Open Responses passed 11 tests. Its separate factory/configuration reuses the
  shared Responses engine through the public SwiftAIOpenAI hosting API, with
  explicit generic Responses mode and no OpenAI credentials or routing. The
  dependency remains explicit to avoid maintaining a second engine. QuiverAI
  composes this package and passed 22 tests including its language surface.
- MCP passed 130 tests. Its client, transports, OAuth, Apps metadata and event
  adapters depend on the core tool layer; core does not import MCP.
- Azure passed 29 tests with native OpenAI/compatible and DeepSeek hosting
  configurations, preserving deployment identity, token transport and MAI routes.
- Optional UI passed 84 tests. UI messages, conversion/validation/reduction,
  observable chat state, direct transport and agent-to-UI stream conversion moved;
  core agent options remain independent of the UI package.
- Gateway passed 35 standalone tests, including HTTP and duplex speech envelope
  behavior. The gateway error value stays in core; provider error parsing, models,
  routing and authentication belong to its package.
- xAI passed 47 standalone tests and the final legacy checkpoint passed 22 tests.
  Its Responses and Chat policies are provider-owned hooks into the existing
  public shared engines; audio, media, Files, Batch and realtime moved together.
- The five generic JSON media adapters moved to core utilities with neutral HTTP
  and error-policy configuration. Legacy constructors preserve their old behavior;
  the existing metadata test passed after the move.
- The syntax audit found all 3545 baseline tests plus four new tests. Assertions
  and attributes match exactly in 3534 originals; the other 11 only rename the
  typed settings constructor/argument inside an error expectation. No test is missing.
- The all-package run passed 3549 tests across 52 packages and the compatibility
  suite, with 33 explicit live skips. The complete dependency closure compiled for
  iOS 15 using the installed simulator SDK; this is compilation, not device execution.
- Fresh graphs contain 9498 public compiler records. 6761 M0 records match. One
  old synthesized convenience member belongs to the internal Vertex TTS class;
  it was never a public nominal type. A normal-import client retains the public
  `SpeechModel.generateSpeech` call, and a negative client confirms that the
  implementation class is inaccessible. Both observations are recorded separately.
- Core isolation, four provider consumers, independent provider version selection,
  incompatible core rejection and the repaired pilot publication rehearsal passed.
  All examples compiled and both offline MCP OAuth flows passed. Tooling tests
  passed 19 checks with the existing historical M1 snapshot check skipped.
- All 52 independently exported Git trees passed their 1828 standalone tests.
  105 normal-import clients passed: minimum and latest compatible dependencies
  for each package, plus a mixed published/candidate provider selection. Two
  exports from the same snapshot were byte-identical. Real public 1.0.0 tags
  supplied the lower bounds where available; other tags are disposable fixtures.
- A repeat root run during competing compiler workloads exposed the existing
  1 ms agent timeout race. Isolated cold-start checks also sometimes expired
  before the mock began. The relevant runtime bytes and assertions match M5.
  The final serial full root suite passed all 1721 tests, including that check.
  The failure logs and investigation remain recorded; passing the full suite
  does not eliminate this known timing sensitivity.
- Final documentation checks passed with no diagnostics; the site builds 98 pages.
  Exact-commit hosted Swift 6.3.3 CI and Pages deployment remain pending.
  [verification.json](verification.json) links the bounded local receipts;
  [distribution-verification.json](distribution-verification.json) records all
  package exports, dependency selections and log hashes.

The M0–M5 evidence and published `modular-pilot` release set remain unchanged.
New extraction does not itself establish publication or full upstream parity.
The pinned Google and Vertex upstream factory sources/tests were read at the
existing inventory snapshot `682e2dd71456f14f9da33a1b983d1998c3a1184c`;
that snapshot is still not asserted to match each npm release.
