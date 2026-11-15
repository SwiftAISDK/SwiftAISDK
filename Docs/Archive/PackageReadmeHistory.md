# Package README History

Package README texts as they stood on 2026-11-15, before each README was reduced
to a short entry point that links to its docs-site guide. Current usage lives in
the docs site and `docs-site/scripts/provider-guides`. Headings are demoted one
level. See [Archive policy](README.md).

## Packages/swift-ai-alibaba/README.md

## SwiftAIAlibaba

Swift-native port of `@ai-sdk/alibaba`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIAlibaba

let provider = try AlibabaProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-alibaba
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/alibaba.md) for authentication, options and supported surfaces.

## Packages/swift-ai-amazon-bedrock/README.md

## SwiftAIAmazonBedrock

Swift-native port of `@ai-sdk/amazon-bedrock`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.
Sources are owned by the canonical repository, with shared HTTP/SigV4 machinery
in core and Anthropic wire behavior in the Anthropic package.

Existing baselines and documented port gaps remain unchanged. See the canonical
provider guide and `Porting/map.json`.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/amazon-bedrock.md) for authentication, options and supported surfaces.

The reviewed Claude 5/5.5 model families support native output schemas and strict
tools where the Bedrock model catalog declares support. Native output is selected
automatically only for schemas it can preserve. Explicit `structuredOutputMode`
continues to select output-format or JSON-tool behavior. Unknown future Claude
aliases retain conservative capability handling.

A named tool choice on Anthropic models that support forced tool use keeps all
function tools and disables parallel tool use by default. Explicit
`disableParallelToolUse: false` opts out. Other model families receive only the
named tool. Top-level image `seed: 0` is preserved. Foreign empty signature-text
parts are omitted before final assistant-prefill trimming.

## Packages/swift-ai-anthropic-aws/README.md

## SwiftAIAnthropicAWS

Swift-native port of `@ai-sdk/anthropic-aws`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.
Sources are owned by the canonical repository, with shared HTTP/SigV4 machinery
in core and Anthropic wire behavior in the Anthropic package.

Existing baselines and documented port gaps remain unchanged. See the canonical
provider guide and `Porting/map.json`.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/anthropic-aws.md) for authentication, options and supported surfaces.

Claude Platform on AWS supports Anthropic message threads through the canonical
`providerOptions.anthropic.thread` create/continue objects. AWS authentication and
workspace headers remain provider settings; keep full conversation history locally
for thread-expiry recovery. Bedrock InvokeModel is a separate hosting surface and
does not enable message threads.

## Packages/swift-ai-anthropic/README.md

## Swift AI Anthropic

An independent Swift-native port of the provider-facing Vercel AI SDK package
`@ai-sdk/anthropic`. Messages, streaming, tools, structured output, decisions/evaluation, batches, Files management and skills.

Swift 6.3 or newer; declared platforms macOS 12 and iOS 15. This source is
maintained in the canonical SwiftAISDK repository and exported as an independently
versioned Swift package. Swift versions are independent of the npm baselines.

### Usage

Depend on `.product(name: "SwiftAIAnthropic", package: "swift-ai-anthropic")`.
For generation and explicit registries also add `swift-ai-core` and its `SwiftAI`
product. The canonical [example](../../Examples/AnthropicOnly) contains a complete
manifest for local development and runs offline with an injected transport.

```swift
import SwiftAI
import SwiftAIAnthropic

let provider = try AIProviders.anthropic(
    configuration: AnthropicProviderSettings(apiKey: "your-api-key")
)
let model = try provider.languageModel("your-model-id")
let result = try await AI.generateText(
    model: model,
    request: .init(messages: [.user("Hello")])
)
```

Native factories use typed `configuration:` settings. The legacy `settings:`
overloads belong to `SwiftAISDK`. When importing both facades, qualify `SwiftAI.AI`
or `SwiftAISDK.AI` and the appropriate factory namespace. Core uses explicit model
objects or registries; it does not initialize an implicit Gateway.

Runtime dependencies are core contracts, transport and utilities only. Bedrock,
Vertex and MiniMax policy remains with those hosting providers; wire adapter
configuration allows the aggregate to reuse Messages behavior without a reverse
provider dependency. Files support buffered upload, metadata lookup, streaming
download and deletion. Streaming upload remains unsupported.

Message threads are opt-in per request through `providerOptions.anthropic.thread`:
`["type": "create"]` starts a thread, while `["type": "continue",
"previousMessageId": "msg_..."]` sends only the new turns. Keep full history locally
for recovery after expiry. Continuations omit supplied leading system instructions
and tool definitions from the wire, while retaining local tool-name handling;
start a new thread to change those definitions. Pin content-specific beta headers
with `anthropicBeta` on every turn. Threads reject compaction/context edits except
`clear_thinking_20251015` with `keep: "all"`, and cannot be used in batches.
Anthropic and Claude Platform on AWS enable this feature; other hosting adapters
must explicitly opt in via `AnthropicModelConfiguration.supportsMessageThreads`.

Mid-conversation system `toolChanges` may add a function/provider tool by value
using `tool`, or add/remove by reference using `toolName`. Inline definitions are
stable across unary/streaming requests and enable the inline-tools beta. Computer
use tools must be declared at the top level and referenced by name. Forced tool
fallbacks preserve the caller's selected tool set, including MCP/inline tools.

Set `includePings: true` in Anthropic provider options to receive `.ping` stream
parts. It defaults to false and is never sent in the request body. Applied service
tier is returned as `providerMetadata.anthropic.serviceTier`; request admission
accepts `auto` or `standard_only`, with a warning for known incompatible tiers.
Native structured output is selected automatically only when its grammar preserves
the requested schema; open maps and recursive schemas retain the JSON-tool path.

### Current provider behavior

Use `provider.extractionModel("claude-sonnet-5-5")` for experimental typed field extraction with nullable answers. The Messages adapter splits more than 16 fields into parallel requests under Anthropic's schema union limit and preserves shared cancellation. The `claude-fable-5-2` model uses the same adaptive thinking and forced-tool fallback policy as 5-1; disabled/budget thinking and sampling are removed with warnings where unsupported.

Dated base Fable 5 aliases remain distinct from minor versions: `claude-fable-5-20260601` follows base-5 policy, while exact or dated `claude-fable-5-2` aliases follow 5.2. This bounded matching corrects an upstream substring collision. Hosting adapters retain their structured-output settings and the documented forced-tool fallback.

### Porting and verification

Run `swift test --package-path Packages/swift-ai-anthropic --no-parallel` from the
canonical checkout. Full verification is `node Scripts/test-packages.mjs`, followed
by `node Scripts/verify-provider-isolation.mjs` and
`node Scripts/verify-provider-versions.mjs`. The latter uses synthetic local Git
tags, not released version histories.

`Porting/map.json` owns source/test/fixture relationships. Reviewed npm versions,
archive evidence and test snapshot dispositions remain in the canonical
`Porting/upstream-lock.json`. Extraction does not advance baselines or claim new
upstream parity. Cross-package wire APIs support port adapters; prefer the typed
provider factory for application code.

Licensed under Apache-2.0; see LICENSE. Vercel names identify provenance, not
affiliation. Contribute through the canonical SwiftAISDK repository. Distribution repositories are generated from it.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

## Packages/swift-ai-assemblyai/README.md

## SwiftAIAssemblyAI

Swift-native port of `@ai-sdk/assemblyai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIAssemblyAI

let provider = try AssemblyAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-assemblyai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
### Behavior notes

Transcription errors preserve AssemblyAI's flat `{ "error": "message" }` response as well as the older nested error shape on upload, submission and polling failures.

## Packages/swift-ai-azure/README.md

## SwiftAIAzure

Swift-native port of `@ai-sdk/azure`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIAzure

let provider = try AzureOpenAIProvider(resourceName: "my-resource",
    configuration: .init(apiKey: "..."))
let model = try provider.languageModel("deployment")
```

Azure owns its deployment/Foundry routing, token transport, MAI and Speech adapters.
OpenAI/compatible and DeepSeek implementations are reused through their explicit
hosting configurations. Existing capabilities and gaps remain unchanged.

Run `swift test --package-path Packages/swift-ai-azure` in the canonical checkout.
Distribution manifests and repositories are generated from the package catalog.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/azure.md) for authentication, options and supported surfaces.

## Packages/swift-ai-baseten/README.md

## SwiftAIBaseten

Swift-native port of `@ai-sdk/baseten`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIBaseten

let provider = try BasetenProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-baseten
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
### Behavior notes

Chat requests accept `providerOptions.baseten` and portable reasoning options. For the serverless `deepseek-ai/DeepSeek-V4-Pro-0813` endpoint, JSON output with reasoning enabled uses an injected system instruction instead of server JSON constraints and returns a compatibility warning. Explicit reasoning `none`, other models and dedicated `modelURL` deployments retain their response format.

## Packages/swift-ai-black-forest-labs/README.md

## SwiftAIBlackForestLabs

Swift-native port of `@ai-sdk/black-forest-labs`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIBlackForestLabs

let provider = try BlackForestLabsProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-black-forest-labs
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/black-forest-labs.md) for authentication, options and supported surfaces.
### Behavior notes

Image submissions without `polling_url` use the configured `/get_result?id=...` endpoint. Only that fallback retries registration delays reported as `Task not found`, for at most 20 attempts and within the polling timeout. Explicit polling URLs and unrelated HTTP 404 errors fail without those retries.

## Packages/swift-ai-bytedance/README.md

## SwiftAIByteDance

Swift-native port of `@ai-sdk/bytedance`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIByteDance

let provider = try ByteDanceProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-bytedance
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-cartesia/README.md

## SwiftAICartesia

Swift-native port of `@ai-sdk/cartesia`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAICartesia

let provider = try CartesiaProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-cartesia
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/cartesia.md) for authentication, options and supported surfaces.
### Behavior notes

Speech options include `volume` (0.5–2), the supported `emotion` values, `locale`, `normalization` and `pronunciationDictionaryId`. Locale overrides the generic language with a warning and conflicts with a provider language. Streaming transcription accepts up to 100 `keyterms` plus `turnStartThreshold`, `turnEagerEndThreshold`, `turnEndThreshold` and integer `turnEndTimeoutMs`; thresholds are omitted with warnings when turn detection is disabled.

## Packages/swift-ai-cerebras/README.md

## SwiftAICerebras

Swift-native port of `@ai-sdk/cerebras`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.
### Behavior notes

`providerOptions.cerebras.queueThreshold` accepts an integer from 50 to 20,000 and sets the `queue_threshold` header, overriding caller header casing. Other dynamic `cerebras` options retain upstream pass-through behavior, including future service tiers. Returned `service_tier` is exposed as `providerMetadata.cerebras.serviceTier`; streams retain the last non-null effective tier.

Model request metadata includes the actual configured request URL in both unary and streaming calls. Refusal strings are surfaced as text and turn a stopped response into `content-filter`; ordinary tool-call and structured-output finish handling is retained.

## Packages/swift-ai-cohere/README.md

## SwiftAICohere

Swift-native port of `@ai-sdk/cohere`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/cohere.md) for authentication, options and supported surfaces.
### Behavior notes

Partial document citations are accepted, including streaming `citation-start` events. Tool-only citations remain in the raw response and do not produce document sources. Response metadata prefers the v2 `id`; missing token usage stays unknown, while billed units remain in raw usage. Tool replay preserves valid JSON argument text and quotes malformed text as a JSON string.

### Current upstream review

The reviewed baseline is `@ai-sdk/cohere` 4.0.83. Published runtime source, declarations and matching-release tests are unchanged from 4.0.78 apart from dependency/version propagation. The user-agent suffix now identifies the reviewed npm baseline. Existing partial citations, usage and streaming behavior are retained; no broader parity claim is added.

## Packages/swift-ai-core/README.md

## Swift AI core

Shared runtime of the independent Swift-native port of Vercel AI SDK. This
package is maintained in the canonical SwiftAISDK repository and exported as an
independently versioned Swift package. Swift versions are independent of npm baselines.

It requires Swift 6.3 or newer and declares macOS 12 / iOS 15. The package has no
external dependencies and contains four products:

| Product | Purpose |
| --- | --- |
| `SwiftAIProvider` | Model protocols, request/result values, stream parts, errors and cancellation primitives |
| `SwiftAITransport` | Foundation HTTP/WebSocket transport, protected downloads, SSE and multipart |
| `SwiftAIProviderUtilities` | Shared conversions, schema validation, stream normalization and provider helpers |
| `SwiftAI` | Generation, tool execution, middleware, telemetry, agents and explicit provider registries |

Depend on `.product(name: "SwiftAI", package: "swift-ai-core")`. Import `SwiftAI` to use
the facade and shared types. Implement `LanguageModel`, then call:

```swift
let result = try await AI.generateText(
    model: myModel,
    request: LanguageModelRequest(messages: [.user("Hello")])
)
```

The core does not supply concrete provider factories or an implicit Gateway.
Build an `AICustomProvider`, register it with `createProviderRegistry`, and resolve
a model explicitly. Decision/evaluation `.modelID` references require the
explicit resolver initializer on `AICustomProvider`; otherwise use `.model(...)`.
The legacy `SwiftAISDK` aggregate retains its string overloads, default-provider
behavior, `customProvider(...)` convenience functions and built-in factories.
Use qualified `SwiftAI.AI` / `SwiftAISDK.AI` when importing both facade modules.

`AIProviderHTTPClient` is the neutral request kernel for adapters. It supports
injected transports, dynamic headers and request URL construction; authentication
policy and provider-specific error parsing belong to the adapter. Download
security, demand-driven bodies and cancellation remain enforced by the transport.
Cross-package helpers are public; orchestration-only helpers use package access.
Public helper signatures are part of the Swift package compatibility contract.
Application code should normally use the facade and typed provider factories.

Core 1.2 constructor and `AIRealtimeSession.connectServer` selectors remain
available as exact function references. Forwarding overloads retain their original
defaults while the new timing, uploaded-video, request URL, tool metadata,
capability and realtime-intent APIs remain available. Existing initializers do
not invent values for new optional fields; server sessions default to conversation.

`AISteering.queue` starts queued tasks one at a time after the current task
finishes; immediate `steer` messages take precedence. Delivered messages are
available as stream parts with delivery IDs and step numbers. URL transcription
uses `AudioURLTranscriptionRequest`, with a native provider hook and protected
download fallback. Shared timestamp requests and `TranscriptionResult.words`
expose provider-supported timings. Video results can contain `uploadedVideos`
descriptors for caller-storage delivery without a downloadable URL.

High-level text/object request URLs and `Telemetry.Event.requestURL` contain only
HTTP(S) origins. Content capture settings filter SDK-owned raw provider payloads.
Realtime event `usage` exposes provider snapshots without changing existing event
case arity. Consumers with exhaustive switches over `LanguageStreamPart` must
handle the new ping, request-metadata and delivered-steering cases.
Exhaustive switches must also handle `.provider` on `AIRealtimeConnectionKind`
and `AIModelCapabilities.Realtime.Connection`, plus `.video`, `.reranking` and
`.decision` on `AIModelCapabilitySection`. These additive enum cases follow the
project's minor-release convention; existing exhaustive switches need migration.

Run `swift test --package-path Packages/swift-ai-core --no-parallel` from the
canonical repository. `node Scripts/verify-core-isolation.mjs` copies this package
and the `Examples/CoreOnly` client outside the repository and builds/runs the
client without aggregate sources. Existing mixed provider/core regressions remain
in the root test suite and must also pass.

Upstream package versions and candidate source/test relationships are in
`Porting/map.json` and the canonical `Porting/upstream-lock.json`. Module extraction
does not update npm baselines or claim new upstream parity. The runtime retains
the existing batch raw-finish-reason interpretation for compatibility; provider
implementation dependencies are absent.

Licensed under Apache-2.0; see LICENSE. Vercel AI SDK names describe provenance,
not affiliation or endorsement. Contribute through the canonical SwiftAISDK
repository, rather than editing generated distribution repositories.

Experimental extraction is available through `AI.experimentalExtract`. Pass an
`AIExtractionModelV4`, shared `AIDecisionState`, and named `AIExtractionField`
descriptors for text, numbers, dates, times, datetimes, durations, or lists.
The facade validates every answer, confidence, number constraint and evidence
source; a refusal rejects the entire operation. A typed answer's `value == nil`
represents upstream JSON null. Text-source offsets use UTF-16 code units.
`AIExtractionLanguageModel` adapts structured language output and supports
parallel field groups with sibling cancellation and complete-usage aggregation.
A direct adapter call preserves provider answers; the facade performs final
field-value validation. `ModelCapability.extraction` is a new enum case.

`LanguageModelRequest.experimentalDownload` receives ordered URL requests with
cancellation and model URL-support information. It covers prompt assets and
model-generated file URLs. A nil prompt download preserves the URL; generated
files require bytes. `createDownload(transport:maxBytes:)` captures a protected
transport. Experimental decision and extraction calls also accept a `download`
callback. Swift retains its native DNS-pinned default for untrusted URLs; this
is intentionally stronger than the current unguarded JavaScript default.

Built-in structured-array streams scan new text and validate completed elements
once, keep the last item pending until the next begins or the envelope closes,
and retain legacy parsing for nonstandard envelopes. Parser state belongs to
each stream. Provider `LanguageModel.telemetryRedactor` hooks sanitize only
SDK-owned metadata copies; prompts, tool results and application context are
preserved. Nested telemetry integrations see sanitized provider result/error
views while callers receive the original forwarded results and errors. A failed
redactor omits the affected metadata. These hooks do not redact arbitrary user
content or promise general secret detection.


### Signed streaming approvals and mixed video results

Core 1.5 adds explicit `toolApprovalSecret:` streaming overloads while preserving
all existing selectors. Signed historical approvals are verified and refined
once before execution; a changed operation is rejected. Existing unsigned stream
overloads retain their behavior.

`VideoGenerationResult.videoURLDescriptors` carries per-URL MIME types for mixed
video results. Async multi-operation generation preserves these descriptors;
`urls`, the common `mediaType` and existing initializers remain available.

## Packages/swift-ai-deepgram/README.md

## SwiftAIDeepgram

Swift-native port of `@ai-sdk/deepgram`, reviewed through npm 3.1.53. The canonical
SwiftAISDK repository owns all source edits; this repository is its deterministic
standalone export.

```swift
import SwiftAIDeepgram
import SwiftAIProvider

let provider = try DeepgramProvider(configuration: .init(apiKey: "..."))
let live = try provider.streamingTranscriptionModel("nova-3")
let result = try await live.stream(.init(
    audio: .chunks([pcm16Audio]),
    inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 16_000),
    providerOptions: ["deepgram": .object([
        "language": "en",
        "streaming": .object(["interimResults": true, "endpointing": 300])
    ])]
))
for try await part in result.stream {
    // Consume partial/final transcripts, metadata and the final aggregate.
}
```

Streaming uses `/v1/listen` and accepts raw PCM16, μ-law (`audio/pcmu`) or A-law
(`audio/pcma`) bytes with an explicit positive sample rate. Flux uses a different
v2 protocol and is rejected. `AIStreamingAudioInput.makeStream()` supports a live
producer; finish its writer to send `CloseStream`, or cancel the result to stop
input and close the connection. Keepalive runs while input is open. Final text is
ordered by time and channel; usage seconds come only from provider metadata.
`includeRawChunks` preserves unknown provider events. Awaited native sends provide
transport backpressure. Settings accept an injected `AIDuplexWebSocketTransport`
and an async `apiKeyProvider`; per-call authorization overrides are honored.

Provider options under `deepgram.streaming` include `interimResults`,
`endpointing` (a nonnegative integer or false), `channels`, `multichannel`,
`vadEvents` and `utteranceEndMs` (at least 1000). Batch transcription ignores this
object with an unsupported warning. Shared options are filtered for streaming;
unsupported active batch options produce warnings.

Speech `callback` is rejected before making a request because Deepgram returns a
JSON acknowledgement instead of audio. `callbackMethod` alone is ignored with a
warning. Use the REST API directly for asynchronous callback delivery. Existing
batch transcription and speech factories remain available.

Run `swift test --package-path Packages/swift-ai-deepgram --no-parallel` from the
canonical checkout. `Porting/map.json` records reviewed coverage and native
adaptations. Live network/provider behavior is not part of the deterministic suite.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

## Packages/swift-ai-deepinfra/README.md

## SwiftAIDeepInfra

Swift-native port of `@ai-sdk/deepinfra`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIDeepInfra

let provider = try DeepInfraProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-deepinfra
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-deepseek/README.md

## SwiftAIDeepSeek

Swift-native port of `@ai-sdk/deepseek`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIDeepSeek

let provider = try DeepSeekProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-deepseek
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/deepseek.md) for authentication, options and supported surfaces.
### Behavior notes

Tool replay preserves valid JSON argument text and quotes malformed text as a JSON string. Native DeepSeek Chat Completions strict tools still require the beta endpoint and consistent strict mode. Azure-hosted adapter configurations have unknown strict-tool capability and forward each tool's explicit true/false/omitted choice without imposing the native beta policy.

### Current upstream review

The reviewed baseline is `@ai-sdk/deepseek` 3.0.86. The existing `languageModel`/`chatModel` factories retain Chat Completions. Opt into Responses and provider web search explicitly:

```swift
let model = provider.responses("deepseek-v4-pro")
let result = try await model.generate(.init(
    messages: [.user("Find the latest release notes.")],
    tools: ["search": DeepSeekTools.webSearch()],
    providerOptions: DeepSeekResponsesModelOptions(reasoningEffort: .high).providerOptions
))
```

Responses supports structured JSON, image URLs/inline images/provider references, ordered reasoning/tool replay, and unary or incremental SSE results. Reasoning `itemId`, full web-search call/action replay, response IDs, logprobs and exact server-tool usage survive in provider metadata. `thinking: .disabled` sends reasoning effort `none`; portable reasoning maps `medium` to `high` and `xhigh` to `max`, with compatibility warnings. `topLogprobs` and ASCII `userID` are validated before HTTP.

Strict tools, seed, topK, penalties and stop sequences produce unsupported warnings. Image URLs are limited to 8192 UTF-16 units, supported inline formats are JPEG/PNG/GIF/WebP, and `fileData` image mode is rejected for Responses. Incomplete/failed/abruptly-ended streams retain their terminal distinction. Model-level behavior is mock-tested; no live-service guarantee is implied.

## Packages/swift-ai-elevenlabs/README.md

## SwiftAIElevenLabs

Swift-native port of `@ai-sdk/elevenlabs`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIElevenLabs

let provider = try ElevenLabsProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-elevenlabs
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/elevenlabs.md) for authentication, options and supported surfaces.
### Behavior notes

`providerOptions.elevenlabs.sourceUrl` sends `source_url` instead of uploading a file. A nonempty audio input is ignored with a warning when this option is present; nil or null retains file upload.

## Packages/swift-ai-fal/README.md

## SwiftAIFal

Swift-native port of `@ai-sdk/fal`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIFal

let provider = try FalProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-fal
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-fireworks/README.md

## SwiftAIFireworks

Swift-native port of `@ai-sdk/fireworks`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIFireworks

let provider = try FireworksProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-fireworks
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-fish-audio/README.md

## SwiftAIFishAudio

Swift-native port of `@ai-sdk/fish-audio`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIFishAudio

let provider = try FishAudioProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-fish-audio
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-gateway/README.md

## SwiftAIGateway

Swift-native port of `@ai-sdk/gateway`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIGateway

let provider = try GatewayProvider(configuration: .init(apiKey: "..."))
let model = try provider.languageModel("openai/gpt-5")
```

The package owns Gateway authentication, model and management routes, batch,
streaming audio and decision/evaluation adapters. Provider-neutral contracts and
socket lifecycle support come from `swift-ai-core`. The reviewed upstream
baseline is `@ai-sdk/gateway` 4.0.145.

`provider.realtimeModel("openai/gpt-realtime-2")` speaks Gateway's normalized
protocol. It supports short-lived client-secret WebSockets with team subprotocols
and trusted server WebSockets with freshly resolved headers. Use
`getResolvedServerWebSocketConfig()` with async credentials, or
`AIRealtimeSession.connectServer` from `SwiftAI` for the shared socket lifecycle.
The realtime route rejects transcription intent; streaming transcription keeps
its existing separate route. Usage stays in the original event envelope and is
available through `AIRealtimeServerEvent.usage`.

`GatewayTools.deepseekSearch` and `deepseekFetch` add Gateway-executed standalone
web tools. Their results and structured errors remain JSON, including
`retryAfter`, `statusText` and future additive fields, in unary and streamed tool
results. Generation info exposes optional `marketCost`, `surchargeCost` and
`gatewayCost`, preserving reported zero values.

Transcription returns independent `words` while retaining `segments`. The shared
`timestampGranularities` option is unsupported by the Gateway wire adapter and
produces a warning. Video results expose `uploadedVideos` for assets stored by
the provider even when no downloadable URL or base64 payload is returned.

An empty configured API key falls through to the Vercel OIDC environment token,
which is resolved for each request. A nonempty key remains selected if it is
invalid; async API key callbacks must return a nonempty key. Native construction
still reports missing credentials immediately.

`gateway.experimental_streamingImageDecoding` is a client-only upstream option.
The native adapter strips it from requests and warns when enabled: image results
still retain buffered base64 strings because the native incremental JSON/binary
response parser is not implemented. No reduced-memory or byte-result behavior
is claimed. Browser media ownership remains separate from native WebSockets.

Run `swift test --package-path Packages/swift-ai-gateway` in the canonical checkout.
Distribution manifests and repositories are generated from the package catalog.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/gateway.md) for authentication, options and supported surfaces.

### Current upstream review

The reviewed baseline is `@ai-sdk/gateway` 4.0.145. `GatewayProviderOptions(headquarters: ["US", "DE"])` forwards country routing restrictions; prefix each code with `!` for exclusions. Other Gateway options remain available in `additionalOptions` and open JSON provider options.

`GatewayTakoSearchConfig` adds developer-only `variableCost`, `maxVariableCostUSD` and `extraBody`. Set the cost cap to `.null` to remove it, or omit it to retain the server default. These settings remain camelCase tool factory arguments; model-input fields are separate. Tako results retain variable-cost usage, premium/redacted row metadata, total matches, relevance scores and placeholder cards without lossy decoding. Browserbase fetch calls preserve `allow_redirects` in tool input. The upstream switch to Zod Mini and JavaScript bundle/type changes do not alter Swift runtime schemas.

## Packages/swift-ai-gladia/README.md

## SwiftAIGladia

Swift-native port of `@ai-sdk/gladia`, reviewed through npm 3.0.82. Source edits
belong to the canonical SwiftAISDK repository and are exported deterministically.

```swift
import SwiftAIGladia
import SwiftAIProvider

let provider = try GladiaProvider(configuration: .init(
    apiKey: "...", pollIntervalMs: 1_000, pollTimeoutMs: 600_000
))
let model = try provider.transcriptionModel("solaria-3")
let result = try await model.transcribe(.init(
    audio: wavData,
    providerOptions: ["gladia": .object([
        "languageConfig": .object(["languages": .array(["en"])]),
        "piiRedaction": true,
        "piiRedactionConfig": .object(["processedTextType": "MASK"])
    ])]
))
```

`transcriptionModel()` uses the native `"default"` sentinel, which omits the model
field and lets Gladia select its default. Explicit `"default"` behaves the same;
other explicit model IDs are sent unchanged. Solaria 3 expects exactly one language and
no code switching; incompatible settings produce warnings. Use
`languageConfig.languages` and `languageConfig.codeSwitching`. Legacy `language`,
`detectLanguage`, `enableCodeSwitching` and `codeSwitchingConfig` are translated
with deprecation warnings; an explicit `languageConfig` fully overrides them.

Boolean `customVocabulary` with `customVocabularyConfig.vocabulary` is the current
format. Legacy vocabulary arrays are translated, invalid entries are ignored with
a warning, and explicit vocabulary configuration wins. Obsolete context prompts,
moderation, chapterization, name consistency, structured extraction, display mode
and `diarizationConfig.enhanced` are ignored with unsupported warnings. Translation
supports batch models, lip sync, context adaptation/context and informal style;
audio-to-LLM accepts a model. PII configuration is validated before upload.

The native `transcribeFromURL(AudioURLTranscriptionRequest)` hook passes a public
HTTP(S) source URL directly to Gladia and skips uploading/downloading the audio.
It uses the same job options, validation, metadata and polling as uploaded bytes.
This is a Swift convenience over the provider's `audio_url` request field.

Provider and per-call `pollIntervalMs`/`pollTimeoutMs` must be positive integers;
per-call options take precedence. Defaults are 1 second and 10 minutes. Polling
and waits honor cancellation. Polling settings never reach the API body. Same-origin
polls include credentials; foreign result origins receive no credentials. The
`x-gladia-version` header defaults to `ai-sdk/3.0.82` and can be overridden.
Audio intelligence results and future add-on fields are preserved in provider
metadata without validating unused response shapes.

Run `swift test --package-path Packages/swift-ai-gladia --no-parallel` in the
canonical checkout. See `Porting/map.json` for reviewed coverage. Workflow
serialization of JavaScript model instances has no native Swift counterpart.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

## Packages/swift-ai-gmicloud/README.md

## SwiftAIGMICloud

Swift-native port of `@ai-sdk/gmicloud`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIGMICloud

let provider = try GMICloudProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-gmicloud
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-google-vertex/README.md

## SwiftAIGoogleVertex

Swift-native port of Vercel AI SDK Google Vertex adapters. Canonical sources are exported as an independent Swift package. Dependencies share Google, Anthropic
and compatible/OpenAI wire implementations rather than copying them.

```swift
import SwiftAIGoogleVertex
let provider = try AIProviders.googleVertex(configuration: GoogleVertexProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

The reviewed upstream baseline is `@ai-sdk/google-vertex` 5.0.140. Gemini
transcription model IDs route to `generateContent`; Chirp and telephony models
retain Cloud Speech routing. Shared word timing requests enable `wordTimestamp`
unless the provider option explicitly disables it. Valid timings appear in
`result.words` and the existing `segments`; segment-only timing requests and
missing requested word timings produce warnings. Options use the first present
`googleVertex`, `vertex`, then `google` namespace.

```swift
let transcription = try provider.transcriptionModel("gemini-3.5-transcribe")
let result = try await transcription.transcribe(.init(
    audio: audioData,
    timestampGranularities: [.word]
))
let live = try provider.streamingTranscriptionModel("gemini-3.5-transcribe-live")
```

Live transcription uses native authenticated WebSockets with 16 kHz PCM audio,
project/location and OAuth credentials. Audio waits for `setupComplete`; interim
text can be revised before final segments. Finish retains provider usage and
language, and cancellation closes the socket and stops input. A quiet three-second
grace window handles servers that omit a terminal signal after audio ends.
`GoogleVertexProvider` accepts an injectable `webSocketTransport`.

Ordinary automatic Vertex-hosted Anthropic native structured output requires
`GoogleVertexHostedProviderSettings.supportsNativeStructuredOutput = true`, a
Claude 4.5+ versioned model ID and a Google Cloud organization policy allowing
`structured_outputs`. It defaults to false and never enables strict tool inputs.
The shared Anthropic explicit `outputFormat` mode and lossless native fallback
for models rejecting forced JSON tools retain their precedence over this
automatic-selection flag.
Shared Google improvements also preserve signed text/function-call order, map
speech language and enforce `toolChoice: none`. The four known Gemini image IDs,
including `gemini-nano-banana-2.1`, declare file input support. Catalog metadata
remains descriptive; it does not prove that a live account enables a feature.

MaaS image downloads and redirects use the shared origin-scoped download policy;
provider credentials are excluded from foreign image origins. Mock tests cover
these contracts. No live account or browser media behavior has been verified.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/google-vertex.md) for authentication, options and supported surfaces.

### Current upstream review

The reviewed baseline is `@ai-sdk/google-vertex` 5.0.140. Gemini 4 Carbon uses the shared Gemini request behavior, and Claude Fable 5.2 uses the existing Anthropic hosting policy. Model identifiers remain open strings.

Tool-result files use the caller-configured download transport without Express Mode API keys. MaaS image downloads and every redirect are validated without cloud bearer tokens or provider headers. Abort signals reach downloads and prevent preaborted work before network I/O. Shared native transport tests cover these guarantees; JavaScript Node/edge browser fallback differences remain platform-specific. No browser or live-service parity is claimed.

## Packages/swift-ai-google/README.md

## SwiftAIGoogle

Swift-native port of the Google adapter from the Vercel AI SDK.

Canonical sources and behavior tests are maintained in
[SwiftAISDK/SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK). This directory is
exported as an independently versioned Swift package. Swift releases and npm
baselines are separate; published release records are in the canonical `Releases/sets`.

```swift
import SwiftAIGoogle
let provider = try AIProviders.google(configuration: GoogleProviderSettings(apiKey: "..."))
let model = try provider.languageModel("gemini-3.6-flash")
```

The reviewed upstream baseline is `@ai-sdk/google` 4.0.120. Gemini speech forwards
an explicit language (except `auto`) for both single and multiple voices.
Interactions accepts string-valued `labels`, maps function and provider tools,
and omits every tool when `toolChoice` is `none`. GenerateContent retains
function calls in their original text order and preserves empty signed thought
blocks when replaying messages. Sparse streamed array indexes are ignored.

Gemini Live supports native WebSockets with ephemeral client tokens or resolved
server credentials:

```swift
let realtime = provider.realtimeModel("gemini-3.8-live")
let server = try await realtime.getResolvedServerWebSocketConfig()
let secret = try await realtime.doCreateClientSecret(.init(expiresAfterSeconds: 60))
```

Use `AIRealtimeSession.connectServer` from `SwiftAI` for the shared native socket
lifecycle. The conversation endpoint rejects transcription intent. Each session
gets a separate parser; `generationComplete` does not close a turn, late output
transcripts retain the preceding turn ID, and unassociated usage snapshots stay
separate from completion. `AIRealtimeServerEvent.usage` preserves reported totals
and known modality counts without inventing missing counts. Server connections
resolve async credentials immediately before use. The synchronous descriptor
is intended for static credentials; use its async counterpart with a supplier.

Browser-owned media capture/playback, speech translation and the separate Google
transcription product remain outside this package's native implementation. Mock
tests verify the reviewed contracts; no live-service parity is claimed.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/google-generative-ai.md) for authentication, options and supported surfaces.

### Current upstream review

The reviewed baseline is `@ai-sdk/google` 4.0.120. `decisionModel("gemini-decision-1")` uses the native `/decisions` endpoint for Choice, Score and Boolean questions. Safety-blocked input returns refusals. Ordered text, JSON, inline media and media URLs are preserved; Box and provider file references are rejected before HTTP.

For source and behavior compatibility, existing non-`gemini-decision-*` IDs passed to `decisionModel` retain the Swift structured-generation adapter, including Box. Use `nativeDecisionModel("custom-decision-id")` to opt any custom or future ID into the native endpoint. This explicit routing differs from the current JavaScript factory, which routes all decision IDs natively. Existing `evaluationModel` semantics are also preserved.

Typed extraction is a distinct contract:

```swift
let extraction = try provider.extractionModel("gemini-3.8-flash")
let result = try await extraction.doExtract(.init(
    state: [.text("The invoice total is 42 EUR.")],
    fields: ["total": .init(type: .number, instructions: "Invoice total", unit: "EUR")]
))
```

Gemini 4 Hydrogen accepts portable and explicit `xhigh` thinking with a `low` minimum. Service-tier metadata falls back to `x-gemini-service-tier` when usage omits the value. Streaming document sources deduplicate by full resource URI, and File Search sources by store and title. Dotted array indexes obey the same contiguous bounds and string continuation as bracket indexes. Vertex shares these request/response algorithms.

## Packages/swift-ai-groq/README.md

## SwiftAIGroq

Swift-native port of `@ai-sdk/groq`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/groq.md) for authentication, options and supported surfaces.
### Behavior notes

`transcribeFromURL` sends HTTP(S) audio URLs without userinfo directly to Groq and removes fragments. It returns nil only for Groq's HTTP 400 redirect-fetch limitation, allowing the facade to use its secure downloader; authentication and other media failures propagate. Plain-text transcription responses work for both URL and file input. Tool replay preserves valid JSON argument text and quotes malformed text.

### Current upstream review

The reviewed baseline is `@ai-sdk/groq` 4.0.83. Published runtime source, declarations and matching-release tests are unchanged from 4.0.78 apart from dependency/version propagation. The user-agent suffix now identifies the reviewed npm baseline. Existing URL transcription, timestamp and language behavior remain unchanged.

## Packages/swift-ai-heygen/README.md

## SwiftAIHeyGen

Swift-native port of `@ai-sdk/heygen` **3.0.25**: asynchronous video generation
and multimodal Decision V4. Maintained in the canonical SwiftAISDK repository and
exported as an independent Swift package.

### Setup

Use the `SwiftAIHeyGen` product. For core operations, also import the `SwiftAI`
product from `swift-ai-core` 1.4.0 or later. The package requires Swift 6.3,
macOS 12 or iOS 15.

```swift
import SwiftAIHeyGen

let provider = try HeyGenProvider(configuration: .init(apiKey: "..."))
```

Set `HEYGEN_API_KEY`, provide `apiKey`, or use `apiKeyProvider` to supply a fresh
key before each authenticated request. Credentials are resolved lazily for both
video and Decision. A missing key now fails the request; the released throwing
initializer signature remains available. Headers use `x-api-key` and the
versioned `ai-sdk-heygen/3.0.25` user agent. Provider and call headers override
defaults case-insensitively, with call headers taking precedence.

Settings also accept a custom `baseURL` (default `https://api.heygen.com`), headers,
query parameters, a deterministic environment map and an injected `AITransport`.
`createHeyGen(configuration:)`, the default `heygen` instance, and
`AIProviders.heyGen(configuration:)` expose the same provider.

### Decide from text, JSON, images and video

```swift
import Foundation
import SwiftAI
import SwiftAIHeyGen

let provider = try createHeyGen()
let model = try provider.decisionModel("heygen-decision-1-turbo")
let result = try await model.doDecide(.init(
    state: [
        .text("Which team should handle this video problem?"),
        .file(mediaType: "video/mp4", data: .url(URL(string: "https://example.com/clip.mp4")!)),
        .file(mediaType: "image/png", data: .reference("your-heygen-asset-id"))
    ],
    questions: [
        "blocked": .boolean(instructions: "Is the customer unable to work?"),
        "team": .choice(
            instructions: "Which team should handle this?",
            criteria: ["video": "Rendering", "account": "Access", "billing": "Payments"]
        ),
        "impact": .score(
            instructions: "How much does this affect the customer?",
            criteria: ["Cosmetic", "Slower", "Blocked"]
        )
    ]
))

let confidence = result.providerMetadata["heygen"]?["confidence"]
```

Decision models call `/v3/models/decisions`. Known IDs are `heygen-decision-1`
and `heygen-decision-1-turbo`; custom IDs pass through unchanged. `decision(_:)`
is a native alias for `decisionModel(_:)`.

Requests support 1–400 questions. Names must be nonempty, without colons or
newlines or leading/trailing whitespace. Choice questions allow 1–255 criteria;
score questions allow 1–10 non-null levels, including a single-level score.
Box questions are unsupported. `maxOutputTokens`, `reasoning` and all HeyGen
provider-specific options produce warnings and are omitted from the request.

Decision accepts up to four images and one video. File inputs may contain `Data`,
existing base64 text, HTTPS URLs or provider-native asset ID strings. Full media
types pass through; `image`/`video` types are detected from inline bytes when
possible. Files are grouped by kind with stable `image-1`/`video-1` names and
preserve order within each group. The model reads images, then video, then state.
Text and JSON remain in the ordered state. A single string/object/array is sent
directly; numbers, booleans and null remain inside an array. Other file types and
non-HTTPS URLs fail before network I/O.

Results preserve boolean probabilities, choice/score probabilities and full
precision. The adapter requires exactly one answer per question. Metadata under
`providerMetadata["heygen"]` preserves `requestId`, per-answer `confidence`,
JSON-valued score `legend` entries and `answerWarnings`. Ancillary response IDs,
model names and usage may be omitted. Response metadata preserves headers and
the complete wire body. Native token counters are integral; nonintegral or
overflowing wire values remain in the raw response and are omitted from typed
usage. HTTP failures retain error codes, parameter names, status and headers.
Pass `abortSignal` in options to propagate cancellation.

`heyGenDecisionModelIDs`, `heyGenDecisionModelLimits` and
`getHeyGenDecisionModelEntry(_:)` expose the published Decision limits and
descriptive capabilities, including for custom model IDs.

### Generate video

The existing `video(_:)` and `videoModel(_:)` APIs retain asynchronous
start/status behavior. `HeyGenVideoModel` implements `AsyncVideoModel`; the core
`AI.generateVideo` operation polls it automatically. Video generation continues
to support text-to-video, first-frame images, typed image/video/audio references,
resolutions and prompt enhancement through `HeyGenVideoModelOptions`.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-heygen --no-parallel
```

Matching-release Decision tests retain the original illustrative fixture and
portable request, asset, limit, response and error scenarios. JavaScript Workflow
serialization is excluded. The shared Swift file-data enum has no inline text-file
or foreign-provider reference-map cases, so those two invalid JS input shapes
cannot compile; direct native asset IDs and other invalid media cases are tested.
Per-file/scenario dispositions and provenance are in `Porting/integration.json`.
Fixture-backed tests do not establish paid or live-service verification.

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/heygen.md) for authentication, options and supported surfaces.

## Packages/swift-ai-huggingface/README.md

## SwiftAIHuggingFace

Swift-native port of `@ai-sdk/huggingface`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIHuggingFace

let provider = try HuggingFaceProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-huggingface
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/huggingface.md) for authentication, options and supported surfaces.

## Packages/swift-ai-hume/README.md

## SwiftAIHume

Swift-native port of `@ai-sdk/hume`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-klingai/README.md

## SwiftAIKlingAI

Swift-native port of `@ai-sdk/klingai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIKlingAI

let provider = try KlingAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-klingai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-lmnt/README.md

## SwiftAILMNT

Swift-native port of `@ai-sdk/lmnt`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-luma/README.md

## SwiftAILuma

Swift-native port of `@ai-sdk/luma`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAILuma

let provider = try LumaProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-luma
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-mcp/README.md

## SwiftAIMCP

Swift-native port of `@ai-sdk/mcp`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

Import `SwiftAIMCP` for `MCPClient`, HTTP/stdio transports, OAuth helpers, MCP Apps
metadata and event delivery adapters. The existing client, transport and tool APIs
are preserved. MCP tool conversion uses `SwiftAI` from `swift-ai-core`; core does
not import MCP. Stdio remains limited to the supported host platforms.

Run `swift test --package-path Packages/swift-ai-mcp` in the canonical checkout.
Runtime and translated tests follow the versions and gaps in `Porting/map.json`
and the canonical version ledger. Distribution manifests are catalog-generated.
### Behavior notes

OAuth discovery rejects HTTPS-to-HTTP redirects before another request. OAuth requests always include a resource: the canonical server URL with its fragment removed is the fallback when custom validation returns nil. A stored refresh token needs its original authorization-server binding; an unbound token must be cleared before dynamic client registration can save a new binding.

MCP Apps CSP metadata includes `baseUriDomains`; known domain arrays discard
non-string values while unknown fields remain available. Streamable HTTP
protocol discovery propagates the original network failure instead of issuing
legacy initialization against the same unreachable endpoint.

OAuth discovery uses the native DNS-pinned GET path for metadata-derived
origins. Untrusted token/registration endpoints require an explicitly supplied
transport that performs connect-time DNS validation. Configured server origins
retain their trust; new `trustedOrigin:` overloads let direct credential calls
identify an explicitly configured origin. This value must come from application
configuration, never response metadata. The original selectors remain available.

## Packages/swift-ai-minimax/README.md

## SwiftAIMiniMax

Swift-native port of `@ai-sdk/minimax`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIMiniMax

let provider = try MiniMaxProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
capabilities and documented gaps remain documented in the provider guide.

`MiniMaxLanguageModelOptions(serviceTier: .priority)` requests priority admission;
`.standard` requests standard admission. Both map to `service_tier` for unary and
streaming Messages. Omit the field for the API default. Priority admission carries
the provider's higher tariff. The `minimax` namespace overrides `anthropic` options;
Anthropic-only admission values produce an unsupported-setting warning.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-minimax
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/minimax.md) for authentication, options and supported surfaces.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

### Current upstream review

The reviewed baseline is `@ai-sdk/minimax` 3.0.81. `image("MiniMax-H3-Image")` and `imageModel("MiniMax-H3-Image-Highspeed")` now support text-to-image and reference-image editing. `MiniMaxProviderSettings.imageBaseURL` defaults to `https://api.minimax.io/v1`; the existing settings initializer selector remains available.

```swift
let image = try await provider.image("MiniMax-H3-Image").generateImage(.init(
    prompt: "A red circle", aspectRatio: "1:1", count: 2,
    providerOptions: MiniMaxImageModelOptions(area: .twoK, outputFormat: .png).providerOptions
))
```

Requests use `/images/generations` or `/images/edits`, always request URL output and securely download successful images through the configured transport. Bearer tokens and provider headers are omitted from downloads. Results contain normalized base64 images, per-image size/revised prompt, output format/request ID and usage details (request usage appears once in per-image metadata).

The maximum advertised batch size is ten. Individual image failures become warnings while successful images survive; seed is unsupported, masks fail before HTTP, and edits warn and omit the generation-only prompt-enhancement option. Compression accepts integers from 0 through 100. Async credentials continue to resolve only for authenticated provider requests.

## Packages/swift-ai-mistral/README.md

## SwiftAIMistral

Swift-native port of `@ai-sdk/mistral`, reviewed through npm 4.0.86. Source edits
belong to the canonical SwiftAISDK repository and are exported deterministically.

```swift
import SwiftAIMistral
import SwiftAIProvider

let provider = try MistralProvider(configuration: .init(apiKey: "..."))
let result = try await provider.streamingTranscriptionModel(
    "voxtral-mini-transcribe-realtime-3"
).stream(.init(
    audio: .chunks([pcm16Audio]),
    inputAudioFormat: .init(mediaType: "audio/pcm", sampleRate: 24_000),
    providerOptions: ["mistral": .object(["targetStreamingDelayMs": 480])]
))
for try await part in result.stream {
    // Consume transcript deltas/finals, metadata and the final aggregate.
}
```

Native streaming transcription uses `/audio/transcriptions/realtime` with PCM16
and a positive sample rate (default 16000). It waits for the session handshake,
splits audio into 64 KiB frames, awaits each send, and finalizes only on
`transcription.done`. Cancellation, provider errors, invalid events and early
socket closure cancel input and close the socket. Untimed speaker segments are
preserved in provider metadata without fabricated timestamps. Usage is retained
unchanged; `includeRawChunks` exposes turn events and unknown messages.

Realtime options include `language`, `contextBias`, `diarize`,
`targetStreamingDelayMs` (80–1200 or 2400), `speakerReferences` and `turnDetection`.
The provider validates diarization/turn compatibility and speaker clip constraints.
Offline transcription warns and ignores the three realtime-only settings;
streaming warns and ignores offline-only return-language, temperature and timestamp
options. Settings accept an injected `AIDuplexWebSocketTransport`; async API keys
resolve separately for each connection.

`provider.voiceSessions.create(modelID:sessionConfiguration:)` creates a managed
voice agent through `/audio/sessions` and returns its ID, participant token and
server URL. `close(sessionID:)` deletes a session. The throwing
`buildSessionConfiguration(_:modelID:update:)` maps supported normalized settings
and strict `mistral` STT/TTS/turn/agent options, rejecting unsupported settings.
`MistralVoiceSessions.parseServerEvent(_:)` maps final user/assistant transcripts,
updates and errors; revised partials emit no appended text and unknown events are
preserved. These are server control and event-mapping APIs. The browser LiveKit
room, microphone, playback, tool RPC and reconnect transport is not implemented;
no managed voice server WebSocket route is advertised.

Chat supports native medium reasoning for `mistral-large-4`/`mistral-large-4-0` and
specific function choice while preserving all declared tools. Conversations keeps
its distinct tool-selection contract. Tool-call argument strings preserve valid
JSON verbatim; non-JSON strings are JSON-quoted. Swift `JSONValue` is a value tree,
so JavaScript BigInt/cyclic-object serialization has no corresponding input shape.

Run `swift test --package-path Packages/swift-ai-mistral --no-parallel` from the
canonical checkout. See `Porting/map.json` for exact reviewed scope and adaptations.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

### Current upstream review

The reviewed baseline is `@ai-sdk/mistral` 4.0.86. Published runtime source, declarations and matching-release tests are unchanged from 4.0.81 apart from dependency/version propagation. The user-agent suffix now identifies the reviewed npm baseline. Existing speech, transcription and language options remain unchanged.

## Packages/swift-ai-moonshotai/README.md

## SwiftAIMoonshotAI

Swift-native port of `@ai-sdk/moonshotai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIMoonshotAI

let provider = try MoonshotAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-moonshotai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/moonshotai.md) for authentication, options and supported surfaces.

### Current upstream review

The reviewed baseline is `@ai-sdk/moonshotai` 3.0.92. MFJS schema conversion now traverses array and tuple children once, retaining existing `prefixItems` before rewritten tuple entries. Nested unions, boolean schemas and source input values preserve their established behavior. The change avoids repeated recursive work for deeply nested array schemas without changing wire output.

## Packages/swift-ai-open-responses/README.md

## SwiftAIOpenResponses

Swift-native port of `@ai-sdk/open-responses`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIOpenResponses

let provider = try OpenResponsesProvider(name: "local", url: "https://example.com/responses",
                                         configuration: .init(apiKey: "..."))
let model = try provider.languageModel("local-model")
```

This package owns endpoint configuration, generic Responses mode, custom tools and
its ported tests. It reuses the existing shared Responses engine through
`SwiftAIOpenAI`'s public hosting API. That dependency does not add OpenAI credentials,
model routing or wire policy. It avoids a second engine to synchronize. A future
engine move would require a separate compatibility migration.

The existing extension-codec gap remains documented in the canonical capability
matrix. Run `swift test --package-path Packages/swift-ai-open-responses` in the
canonical checkout. Distribution manifests are generated from the package catalog.

## Packages/swift-ai-openai-compatible/README.md

## Swift AI OpenAI-compatible

An independent Swift-native port of the provider-facing Vercel AI SDK package
`@ai-sdk/openai-compatible`. Generic chat, completions, embeddings and images. This package does not dispatch to built-in providers or provide OpenAI Responses, audio, files or realtime.

Swift 6.3 or newer; declared platforms macOS 12 and iOS 15. This source is
maintained in the canonical SwiftAISDK repository and exported as an independently
versioned Swift package. Swift versions are independent of the npm baselines.

### Usage

Depend on `.product(name: "SwiftAIOpenAICompatible", package: "swift-ai-openai-compatible")`.
For generation and explicit registries also add `swift-ai-core` and its `SwiftAI`
product. The canonical [example](../../Examples/OpenAICompatibleOnly) contains a complete
manifest for local development and runs offline with an injected transport.

```swift
import SwiftAI
import SwiftAIOpenAICompatible

let provider = AIProviders.openAICompatible(
    configuration: OpenAICompatibleProviderSettings(name: "custom", baseURL: "https://example.com/v1", apiKey: "your-api-key")
)
let model = try provider.languageModel("your-model-id")
let result = try await AI.generateText(
    model: model,
    request: .init(messages: [.user("Hello")])
)
```

Native factories use typed `configuration:` settings. The legacy `settings:`
overloads belong to `SwiftAISDK`. When importing both facades, qualify `SwiftAI.AI`
or `SwiftAISDK.AI` and the appropriate factory namespace. Core uses explicit model
objects or registries; it does not initialize an implicit Gateway.

Runtime dependencies are core contracts, transport and utilities only. The native
`OpenAICompatibleProvider` requires an explicit name/base URL and does not inspect
environment variables. It is distinct from the legacy aggregate class with the
same name; qualify that type when importing both modules. OpenAI model catalog
rules and concrete host policies are supplied by adapters rather than importing
those provider implementations here.

### Current provider behavior

`OpenAICompatibleChatModel.prepareRequest(_:)` returns `(body: JSONValue, warnings: [AIWarning])` for unary generation without sending a request. It applies request transforms and reasoning/option warnings while omitting streaming fields. `convertResponse(body:providerOptions:)` converts an already received JSON body through the same content, tool, usage and metadata logic; the native metadata wrappers remain empty for absent HTTP information. A custom model configuration can set `downloadTransport` for unauthenticated image URLs.

### Porting and verification

Run `swift test --package-path Packages/swift-ai-openai-compatible --no-parallel` from the
canonical checkout. Full verification is `node Scripts/test-packages.mjs`, followed
by `node Scripts/verify-provider-isolation.mjs` and
`node Scripts/verify-provider-versions.mjs`. The latter uses synthetic local Git
tags, not released version histories.

`Porting/map.json` owns source/test/fixture relationships. Reviewed npm versions,
archive evidence and test snapshot dispositions remain in the canonical
`Porting/upstream-lock.json`. Extraction does not advance baselines or claim new
upstream parity. Cross-package wire APIs support port adapters; prefer the typed
provider factory for application code.

Licensed under Apache-2.0; see LICENSE. Vercel names identify provenance, not
affiliation. Contribute through the canonical SwiftAISDK repository. Distribution repositories are generated from it.

## Packages/swift-ai-openai/README.md

## Swift AI OpenAI

An independent Swift-native port of the provider-facing Vercel AI SDK package
`@ai-sdk/openai`. Responses and chat, completions, embeddings, images, transcription/speech, decisions/evaluation, batches, files, skills and the existing OpenAI Live WebSocket adapter.

Swift 6.3 or newer; declared platforms macOS 12 and iOS 15. This source is
maintained in the canonical SwiftAISDK repository and exported as an independently
versioned Swift package. Swift versions are independent of the npm baselines.

### Usage

Depend on `.product(name: "SwiftAIOpenAI", package: "swift-ai-openai")`.
For generation and explicit registries also add `swift-ai-core` and its `SwiftAI`
product. The canonical [example](../../Examples/OpenAIOnly) contains a complete
manifest for local development and runs offline with an injected transport.

```swift
import SwiftAI
import SwiftAIOpenAI

let provider = try AIProviders.openAI(
    configuration: OpenAIProviderSettings(apiKey: "your-api-key")
)
let model = try provider.languageModel("your-model-id")
let result = try await AI.generateText(
    model: model,
    request: .init(messages: [.user("Hello")])
)
```

Native factories use typed `configuration:` settings. The legacy `settings:`
overloads belong to `SwiftAISDK`. When importing both facades, qualify `SwiftAI.AI`
or `SwiftAISDK.AI` and the appropriate factory namespace. Core uses explicit model
objects or registries; it does not initialize an implicit Gateway.

OpenAI depends on the generic compatible package for shared wire behavior; its
runtime does not depend on Anthropic, the aggregate, MCP or UI. Provider-specific
model catalogs, authentication/defaults, Responses and audio behavior are owned here.
`OpenAIProvider` is the native concrete factory type; the legacy OpenAI factory's
`SwiftAISDK.OpenAICompatibleProvider` return type remains unchanged.

### Current provider behavior

The provider exposes `extractionModel(_:)` for experimental typed nullable field extraction through Responses. `providerOptions.openai.textFormat` fixes the initial text format independently of Output parsing; empty system messages can replay `textFormatUpdate`, `reasoningEffortUpdate` and `additionalTools` at their original position. Format changes require GPT-6 or later with standard reasoning and no automatic compaction/truncation. Combine consecutive format and reasoning changes in one empty control message. Additional tools accept function, custom and namespace definitions; hosted adapters also read OpenAI tool-result options.

Set `promptCacheOptions.comparisonResponseId` to request comparison diagnostics. `providerMetadata.openai.promptCacheDiagnostics` preserves their raw fields across unary, streaming and batch results. OpenAI tool credentials are removed from telemetry copies while request/response values returned to applications remain intact. Image file, mask and markup downloads use the configured raw transport, without Azure provider credentials.

### Porting and verification

Run `swift test --package-path Packages/swift-ai-openai --no-parallel` from the
canonical checkout. Full verification is `node Scripts/test-packages.mjs`, followed
by `node Scripts/verify-provider-isolation.mjs` and
`node Scripts/verify-provider-versions.mjs`. The latter uses synthetic local Git
tags, not released version histories.

`Porting/map.json` owns source/test/fixture relationships. Reviewed npm versions,
archive evidence and test snapshot dispositions remain in the canonical
`Porting/upstream-lock.json`. Extraction does not advance baselines or claim new
upstream parity. Cross-package wire APIs support port adapters; prefer the typed
provider factory for application code.

Licensed under Apache-2.0; see LICENSE. Vercel names identify provenance, not
affiliation. Contribute through the canonical SwiftAISDK repository. Distribution repositories are generated from it.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.

## Packages/swift-ai-parallel/README.md

## SwiftAIParallel

Native Swift port of `@ai-sdk/parallel` **3.0.9**, exposing Parallel's web-grounded
Decision V4 API. It supports boolean, choice and score questions, full-precision
answers, refusals, shared evidence citations, confidence, score legends and usage.

### Install

Add the provider package and the core product when using the decision API.
Swift 6.3, macOS 12 and iOS 15 or later are required.

```swift
.package(url: "https://github.com/SwiftAISDK/swift-ai-parallel.git", from: "1.0.0"),
.package(url: "https://github.com/SwiftAISDK/swift-ai-core.git", from: "1.4.0")
```

```swift
.product(name: "SwiftAIParallel", package: "swift-ai-parallel"),
.product(name: "SwiftAI", package: "swift-ai-core")
```

### Make a decision

Set `PARALLEL_API_KEY`, or supply `ParallelProviderSettings(apiKey:)`. The key is
resolved when a request runs. Requests use `x-api-key`, with no generated bearer
Authorization header, and the versioned `ai-sdk-parallel/3.0.9` user agent.

```swift
import SwiftAI
import SwiftAIParallel

let provider = createParallel()
let model = try provider.decisionModel("fast")
let result = try await model.doDecide(.init(
    state: [.json(["company": "Parallel", "website": "https://parallel.ai"])],
    questions: [
        "hasSearch": .boolean(instructions: "Does it offer web search?"),
        "availability": .choice(
            instructions: "Is the API available?",
            criteria: ["available": "Publicly available", "unknown": "Insufficient evidence"]
        ),
        "fit": .score(
            instructions: "How well does it fit?",
            criteria: ["No fit", "Partial fit", "Full fit"]
        )
    ],
    providerOptions: ParallelDecisionModelOptions(includeExcerpts: false).providerOptions
))

let evidence = result.providerMetadata["parallel"]?["citations"]
```

`parallel` is the default provider. `AIProviders.parallel(configuration:)` and
`provider.decision(_:)` are equivalent native factories. Any nonempty model string
is forwarded as the service's `mode`, so new modes do not require a package update.
The default endpoint is `https://api.parallel.ai/v1/decisions`; `baseURL` replaces
the prefix before `/decisions`.

Settings accept custom headers, an injectable `AITransport`, a deterministic
environment map, or an async `apiKeyProvider` that supplies a fresh key before
each authenticated request. Call headers override provider headers. Pass
`abortSignal` in call options to propagate cancellation through the request.

### Inputs and results

State may contain ordered text and JSON parts. A single part is sent directly;
zero or multiple parts are sent as a JSON array. Files and box questions are
rejected before network I/O. Requests require 1–100 questions with ASCII letters,
digits, underscores or hyphens in their names. Choice questions require 2–255
criteria; score questions require 2–10 levels.

`includeExcerpts` is an optional Boolean. Omitting it leaves the service default
unchanged. Unsupported provider options, `maxOutputTokens` and `reasoning` produce
warnings. The adapter requires exactly one response answer for each question and
validates probability ranges, citations and usage. It preserves refusal answers
alongside successful answers; the core decision API applies its own refusal
policy when used to normalize these provider results.

Results preserve full numeric precision without declaring rounding. Metadata at
`providerMetadata["parallel"]` contains `citations`, `confidence`, `legend`,
`decisionId` and `mode`. Citations are shared across the request, without a
per-answer mapping; empty excerpts and explicit null titles are retained.
`ParallelDecisionProviderMetadata` provides a typed Codable view. Response metadata
includes the decision ID, requested model ID, headers and unmodified JSON body.
HTTP errors retain status, retry headers and the wire body in `AIAPICallError`.

`parallelModelCatalog`, `getParallelDecisionModelEntry(_:)` and
`parallelProviderOptions` describe known `fast` support and unknown future-mode
option support. These declarations do not change request validation.

### Verification and platform differences

The exact 3.0.9 release test file is translated into Swift with its original
illustrative JSON fixture: native request/auth/header/options behavior, precision,
citations/refusals, five state forms, seven invalid question forms, malformed
responses, five HTTP statuses, cancellation, warnings, environment defaults,
unsupported models and future modes. JavaScript Workflow-symbol serialization is
excluded because Swift does not expose that JS runtime surface. Native tests add
typed metadata/catalog checks, header precedence, credential suppliers, aborted
calls and response schema edge cases.

```sh
swift test --package-path Packages/swift-ai-parallel --no-parallel
```

Source, fixture hashes and per-scenario dispositions are recorded in
`Porting/map.json` and `Porting/integration.json`. Fixture-backed tests do not
constitute paid or live-service verification. There is no streaming, text, image,
embedding, video or audio generation surface in this provider.

## Packages/swift-ai-perplexity/README.md

## SwiftAIPerplexity

Swift-native port of `@ai-sdk/perplexity`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/perplexity.md) for authentication, options and supported surfaces.
### Behavior notes

Agent requests with `toolChoice: "none"` omit native and function tool definitions and set `max_tool_calls` to zero, including presets. Conversation tool-call history is preserved.

### Current upstream review

The reviewed baseline is `@ai-sdk/perplexity` 5.0.34. Native decisions accept `PerplexityDecisionModelOptions(mode: .webGrounding, maxStaleness: 0)`. `mode` sends `web_grounding`; maximum staleness is a nonnegative integer representing fetched-page age in seconds, including zero.

Results expose `searchResults`, `fetchedResults` and exact `toolCalls` invocation counts under `providerMetadata.perplexity`. Missing invocation counts remain null and reported zeros are preserved. HTTP failures retain grounding-count headers and retryability. Unknown decision options still produce unsupported warnings; invalid grounding options fail before HTTP.

## Packages/swift-ai-prodia/README.md

## SwiftAIProdia

Swift-native port of `@ai-sdk/prodia`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIProdia

let provider = try ProdiaProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-prodia
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-quiverai/README.md

## SwiftAIQuiverAI

Swift-native port of `@ai-sdk/quiverai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIQuiverAI

let provider = try QuiverAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-quiverai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-replicate/README.md

## SwiftAIReplicate

Swift-native port of `@ai-sdk/replicate`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIReplicate

let provider = try ReplicateProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-replicate
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
### Behavior notes

Aborted or exhausted image polling starts best-effort cancellation at the configured prediction endpoint. Cancellation resolves provider credentials again, omits per-call headers and the aborted signal, and preserves the original generation error. Response-supplied cancel URLs are ignored. Image and video seed zero remains a valid explicit seed.

## Packages/swift-ai-revai/README.md

## SwiftAIRevAI

Swift-native port of `@ai-sdk/revai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIRevAI

let provider = try RevAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-revai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-scaledown/README.md

## SwiftAIScaleDown

Native Swift port of [`@ai-sdk/scaledown` 3.0.1](https://www.npmjs.com/package/@ai-sdk/scaledown/v/3.0.1). It provides experimental Decision V4 and Extraction V4 models. Requires Swift 6.3, macOS 12 or iOS 15, and SwiftAI core 1.4.0 or later.

Add `https://github.com/SwiftAISDK/swift-ai-scaledown.git` to Swift Package Manager and select `SwiftAIScaleDown` (initial version 1.0.0). Use the canonical workspace before that tag is published; a source port does not itself establish release availability.

```swift
import SwiftAIScaleDown
import SwiftAIProvider

let provider = createScaleDown(configuration: .init(apiKey: "your-api-key"))
let model = try provider.decisionModel("classify-1")
let decision = try await model.doDecide(.init(
    state: [.text("The export crashes in Safari.")],
    questions: [
        "category": .choice(criteria: ["bug": "Broken functionality", "feedback": nil]),
        "workaround": .boolean(instructions: "Is there a workaround?"),
        "severity": .score(criteria: ["Cosmetic", "Degraded", "Blocking"])
    ]
))
```

The default `scaledown` and `scaleDown` constants refer to the same provider. `AIProviders.scaleDown(configuration:)` is the native factory. Credentials are loaded when a request is made: `apiKeyProvider` supplies a fresh asynchronous key, then an explicit `apiKey`, then `SCALEDOWN_API_KEY`. Pass `environment: [:]` for an isolated environment. The default base URL is `https://api.scaledown.xyz`; `baseURL`, `headers` and `transport` are configurable. Each request carries `x-api-key` and `ai-sdk-scaledown/3.0.1` in its user agent. Call headers override provider headers case-insensitively, and abort signals flow to transport requests.

Decision uses `/v1/scaledown`. `classify` and `classify-1` are upstream aliases; custom model IDs are accepted. Choice criteria with null descriptions use the choice ID as the description. Structured instructions and criteria are encoded as compact JSON text. Boolean criteria become explicit yes/no instructions. Score rubrics require 2–10 non-null levels. Box questions are rejected before network I/O. Results preserve probabilities, token usage, response body/headers/model ID, and `providerMetadata["scaledown"]` confidence, score legend and optional request cost. Unsupported `maxOutputTokens`, `reasoning` and scoped decision provider options produce warnings.

```swift
let extraction = try await provider.extractionModel("extract-1").doExtract(.init(
    state: [.text("Acme Corp. Contacts: Ana, Bo.")],
    fields: [
        "vendor": .init(type: .text, instructions: "Company name"),
        "contacts": .init(type: .list, instructions: "Contact names", items: .text)
    ],
    providerOptions: ScaleDownExtractionModelOptions(threshold: 0.5).providerOptions
))
```

Extraction uses `/v1/chat/completions`; `extract`, `extract-1` and custom IDs are accepted. It supports text fields and lists of text. Number, date, time, datetime, duration and non-text lists are rejected before a request. `threshold` must be between 0 and 1. Scalar fields select the highest-confidence entity, retaining the first on ties; lists preserve entity order. Empty or missing values become `nil`, and missing lists have no item metadata. UTF-8 byte spans are accepted as sources only when they match the exact original text and valid character boundaries, then converted to UTF-16 offsets. JSON evidence is retained in the input but never cited as a text source. OCR matches can cite the file part and expose `providerMetadata["scaledown"]["ocrText"]`. Reference dates and generation settings emit unsupported warnings.

Both models accept ordered text/JSON parts and at most one inline JPEG, PNG, TIFF or PDF document. Use `.file(mediaType: "application/pdf", data: .data(bytes))` or `.base64(value)`. Provider file references and URLs are rejected at the direct provider boundary; a higher-level core API can download URLs before invoking the provider. File-only extraction supplies the upstream default user message. No batching or streaming API is exposed by this upstream package.

HTTP errors retain status, raw body, response headers and retryability through `AIError.apiCall`; a native `detail` string or validation-detail array provides `AIAPICallError.message`. Invalid outer success envelopes fail as non-retryable API errors. `ScaleDownInvalidExtractionContentError` retains the exact inner string in `data` when extraction content is malformed.

The two matching-release upstream test files are translated with their fixture values, request/result expectations, warnings and rejection cases; the per-scenario record is in `Porting/upstream-tests.json`. JavaScript workflow serialization symbols have no Swift workflow equivalent. Swift dictionaries use key equality rather than JavaScript insertion-order assertions, and Swift token counts are integral. Live/paid provider calls are not part of this verification.

```sh
swift test --package-path Packages/swift-ai-scaledown --no-parallel
```

## Packages/swift-ai-tencent/README.md

## SwiftAITencent

Native Swift port of `@ai-sdk/tencent` **3.0.3**, exposing TokenHub Chat Completions and TokenHub Kling / Tencent Cloud VOD video generation. Requires Swift 6.3, macOS 12 or iOS 15.

```swift
import SwiftAIProvider
import SwiftAITencent

let provider = createTencent(configuration: .init(apiKey: "TOKENHUB_KEY"))
let answer = try await provider.chat("hy4").generate(
    LanguageModelRequest(messages: [.user("Hi")])
)
print(answer.text)
```

`TencentProvider`, `createTencent`, the default `tencent` instance and `AIProviders.tencent(configuration:)` share the same settings. `chat`, `chatModel` and `languageModel` route to the shared OpenAI-compatible model with provider identity `tencent.chat`. Chat tools, reasoning, usage, request/response metadata and streaming use that implementation; requests include `ai-sdk-tencent/3.0.3`. The language model is a native alias of `OpenAICompatibleChatModel`.

TokenHub defaults to `https://tokenhub-intl.tencentcloudmaas.com/v1`. Supply `apiKey` or the `TENCENT_TOKENHUB_API_KEY` environment variable. `apiKeyProvider` asynchronously supplies a fresh key before each authenticated request. `baseURL`, `headers` and `transport` support custom endpoints and native HTTP middleware. Missing keys fail at the first request, so creating a video model does not require unused credentials.

```swift
let model = try provider.video("kling-video-v3")
let started = try await model.startVideoGeneration(.init(
    request: .init(prompt: "A cat walking on a beach",
                   aspectRatio: "16:9", durationSeconds: 5,
                   resolution: "1920x1080", generateAudio: true)
))
let status = try await model.videoGenerationStatus(.init(operation: started.operation))
// Persist started.operation to resume polling later.
```

TokenHub accepts `kling-video-*` IDs and routes standard, omni, and motion-control models to their respective endpoints. V4 IDs with references, voices or unframed elements use omni routing. Inputs include first/last frames, image/video references, native byte data and URLs. Audio references are ignored with a warning; use the `voices` option. Unsupported FPS, batch counts, seeds, model options and per-request webhooks produce warnings. Provider-level `resolution` overrides the common width-by-height resolution tier.

```swift
let vod = createTencent(configuration: .init(
    secretId: "SECRET_ID", secretKey: "SECRET_KEY",
    subAppId: "1500000000", region: "ap-singapore"
))
let video = try vod.video("vod/VS/2.0")
var options = TencentVideoModelOptions()
options.negativePrompt = "dogs"
options.enhancePrompt = false
options.assets = [.init(url: "asset://asset-1", usage: "FirstFrame")]
let task = try await video.startVideoGeneration(.init(
    request: .init(prompt: "A cat", providerOptions: try options.providerOptions)
))
```

VOD uses `vod/<ModelName>/<ModelVersion>` IDs and defaults to `https://vod.intl.tencentcloudapi.com`. Settings fall back to `TENCENTCLOUD_SECRET_ID`, `TENCENTCLOUD_SECRET_KEY`, `TENCENTCLOUD_VOD_SUB_APP_ID` and `TENCENTCLOUD_SESSION_TOKEN`. The SubAppId must be a positive safe integer; Swift settings take its decimal string. `sessionToken`, `region` and `vodBaseURL` are optional. VOD credentials are loaded only for VOD requests; TokenHub credentials are independent.

VOD requests use TC3-HMAC-SHA256 signatures and protect signed protocol headers from caller overrides. Native file inputs and `asset://` options retain their media categories and frame/reference roles. Output configuration includes resolution, aspect ratio, duration, audio, compliance, watermark, enhancement and off-peak settings. `TencentVideoModelOptions` validates the complete published schema, including element/voice IDs, asset categories and task priority. Raw options can also be supplied as `providerOptions["tencent"]`.

Both backends expose start/status operations and pending/completed/failed states. Completed results contain video URLs, per-file `videoURLDescriptors` with individual media types, and `providerMetadata["tencent"]` with task/request IDs, duration, resolution, last-frame URL and billing usage when provided. VOD last-frame images are metadata, not video outputs. Enveloped Tencent Cloud failures receive the corresponding status and retryability while preserving the original body and headers. Requests, status checks and polling carry cancellation. Direct `generateVideo` polls at five-second intervals for up to ten minutes; higher-level SwiftAI orchestration provides configurable polling through the async video surface. Download or upload final URL outputs through the higher-level media flow.

Embedding, image, transcription, speech and reranking models are unsupported. JavaScript workflow serialization and Zod module initialization/caching have no Swift surface. Swift's common video request requires a prompt string; an empty prompt represents the upstream absent-prompt scenario and is omitted from the Tencent body. `videoURLDescriptors` retains each VOD URL/MIME association, including mixed MOV, WebM and MP4 outputs; the legacy `mediaType` remains the first video's type. No live provider-service check is claimed.

Matching-release provenance and every upstream test-file/scenario disposition are recorded in `Porting/upstream-tests.json`. The package tests preserve all portable release scenarios and fixtures, including Tencent's published canonical-request and TC3 signature reference values.

## Packages/swift-ai-togetherai/README.md

## SwiftAITogetherAI

Swift-native port of `@ai-sdk/togetherai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAITogetherAI

let provider = try TogetherAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

JSON Schema output is forwarded for the exact verified catalog IDs: DeepSeek
V4 Flash 0731, V4.1 Flash and its 1017 snapshot, GPT OSS 120B, GLM 5.2 and
5.3 Flash, Kimi K3, and MiniMax M3.1 Flash. Other model IDs retain the JSON-object
fallback. Custom settings can explicitly opt additional models into schema output.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-togetherai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-topaz/README.md

## SwiftAITopaz

Swift-native port of `@ai-sdk/topaz`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAITopaz

let provider = try TopazProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-topaz
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/topaz.md) for authentication, options and supported surfaces.

## Packages/swift-ai-typesafe-ai/README.md

## SwiftAITypeSafeAI

Swift-native port of `@ai-sdk/typesafe-ai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAITypeSafeAI

let provider = TypeSafeAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, an environment override and an injected
`AITransport`. Models use the common SwiftAIProvider protocols.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-typesafe-ai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/typesafe.md) for authentication, options and supported surfaces.
### Behavior notes

Decision state preserves a single JSON object, array or string; primitive JSON state becomes text. Choice questions require 1–255 options, and score questions require 1–10 non-null levels. Score legends are exposed under `providerMetadata.typesafe.legend`. A box question may omit instructions using `.box()` (sent as native JSON null) and enables the image feature header even without image assets.

## Packages/swift-ai-ui/README.md

## SwiftAIUI

Optional Swift-native UI layer for SwiftAISDK. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

Import `SwiftAIUI` for UI messages, validation and conversion, stream reduction,
`DirectAIChatTransport`, `AIChatSession`, and `createAgentUIStream`.
`AIChatSession` uses Combine and main-actor isolation for native application state.
The core agent and its request options remain in `swift-ai-core`, which does not
import this package. This is not a port of React components or browser rendering.

Delivered steering messages are persisted with their IDs and step numbers.
Use `convertToModelMessages` to replay steering-containing UI history in the
correct assistant/tool/user order while preserving user content metadata.
The singular converter rejects embedded steering, and validation requires the
user role. Exhaustive switches over `AIUIMessagePart` must handle the new
steering-message case.

Run `swift test --package-path Packages/swift-ai-ui` in the canonical checkout.
Upstream mappings and existing UI gaps remain in `Porting/map.json` and the
canonical capability documentation. Distribution manifests are catalog-generated.

### Queued chat messages

Enable `AIChatSession(transport: transport, experimentalQueue: true)` to queue
messages behind the current response. `experimentalQueuedMessages` is observable;
`experimentalRemoveQueuedMessage(_:)` removes an item and
`experimentalSendQueuedMessageNow(_:)` stops owned work before prioritizing it.
Each message retains its headers, body and metadata. Stop, network errors and
interrupted responses pause the queue until the next explicit send. Edits and
regeneration discard queued history. Pending client tools and approvals hold
queued messages; replied approvals reach the model first. The original
initializer keeps immediate replacement behavior. Native automatic-send callbacks
are synchronous, so browser Promise scheduling is represented by generation and
owned-task cancellation rather than a JavaScript decision queue.

Tool errors preserve the model-visible history by default. Set
`DirectAIChatTransport.errorOptions` or pass `errorOptions` to
`createAgentUIStream`/`AIUIMessageStreamReducer.snapshots` for explicit redaction.
A custom `onError` opts into tool redaction unless `redactToolErrors` is false.
Redaction changes restored history and reports a compatibility warning if later
reasoning is streamed. Prefer throwing safe errors inside tools. Native UI uses
`AIToolResult.isError` for failed-tool display, including invalid-input failures;
browser wire chunk names are not a separate native public event protocol.

UI validation stops at the first invalid message, part or citation and rejects
non-finite numbers in provider/tool metadata with a bounded issue. Swift types
already exclude JavaScript functions, bigint and cyclic object values.

## Packages/swift-ai-vercel/README.md

## SwiftAIVercel

Swift-native port of `@ai-sdk/vercel`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIVercel

let provider = try VercelProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-vercel
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-voyage/README.md

## SwiftAIVoyage

Swift-native port of `@ai-sdk/voyage`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

The canonical repository owns all source edits. This package owns its provider
configuration and wire behavior, using only the declared shared dependencies.
Existing upstream baselines, capabilities and documented gaps remain unchanged.
See `Porting/map.json` and the canonical provider guide.

## Packages/swift-ai-xai/README.md

## SwiftAIXAI

Swift-native port of `@ai-sdk/xai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIXAI

let provider = try XAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Responses request policy, legacy Chat behavior, Files, Batch, realtime and media
adapters belong to this package. It composes the public `SwiftAIOpenAI` Responses
engine and managed-file helpers and the `SwiftAIOpenAICompatible` Chat engine;
these dependencies do not install OpenAI credentials or select OpenAI endpoints.
New code should use `languageModel` or `responses`; `chat` preserves the earlier
Swift compatibility surface removed from upstream xAI 5.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-xai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/xai.md) for authentication, options and supported surfaces.

## Packages/swift-ai-zai/README.md

## SwiftAIZAI

Swift-native port of `@ai-sdk/zai`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

```swift
import SwiftAIZAI

let provider = ZAIProvider(configuration: .init(apiKey: "..."))
```

Settings accept a custom base URL, headers, query parameters and an injected
`AITransport`. Models use the common SwiftAIProvider protocols. Existing upstream
baselines, capabilities and documented gaps remain unchanged.

Run the standalone suite from the canonical checkout:

```sh
swift test --package-path Packages/swift-ai-zai
```

The canonical repository owns all edits. Distribution manifests and repositories
are generated from the catalog; see `Porting/map.json` and the canonical provider guide.
