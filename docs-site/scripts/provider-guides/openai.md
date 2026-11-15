## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.openAI() // reads OPENAI_API_KEY
let model = try provider.languageModel("gpt-6.1-sol")
let result = try await model.generateText("Write one sentence about Swift concurrency.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIOpenAI`, then call
`AIProviders.openAI(configuration: OpenAIProviderSettings(...))`. The native
`configuration` argument has a default, so `AIProviders.openAI()` also works there.

## Umbrella and native providers

| Factory | Returns | Settings |
| --- | --- | --- |
| `AIProviders.openAI(settings:)` (umbrella) | `OpenAICompatibleProvider` | `ProviderSettings` |
| `AIProviders.openAI(configuration:)` (native) | `OpenAIProvider` | `OpenAIProviderSettings` |

Both read `OPENAI_API_KEY` and `OPENAI_BASE_URL`, accept `organization` and
`project` (sent as `OpenAI-Organization` and `OpenAI-Project`), and expose the
same language, completion, embedding, image, speech, transcription, decision,
extraction, files, skills and batch surfaces. Only the native provider offers
`apiKeyProvider`, `webSocketTransport` and `streamingTranscriptionModel(_:)`.

## Language models

- `languageModel(_:)` and `responses(_:)` use the Responses API.
- `chatModel(_:)` (alias `chat(_:)`) uses Chat Completions.
- `completionModel(_:)` uses the legacy Completions API, for example with
  `gpt-3.5-turbo-instruct`.

Provider options go under `providerOptions["openai"]`:

```swift
let result = try await model.generateText(
    "Summarize this design document.",
    options: LanguageGenerationOptions(
        reasoning: "high",
        providerOptions: ["openai": [
            "store": false,
            "parallelToolCalls": false,
            "textVerbosity": "low",
        ]]
    )
)
```

Common Responses keys: `store`, `parallelToolCalls`, `reasoningEffort`,
`reasoningSummary`, `previousResponseId`, `conversation`, `serviceTier`,
`textVerbosity`, `include`, `maxToolCalls`, `promptCacheKey`,
`promptCacheOptions`, `safetyIdentifier`, `user`, `allowedTools` and
`strictJsonSchema`.

### Reasoning

Portable `reasoning` maps to the nearest supported effort, rounding down, and never
silently disables reasoning. An explicit `reasoningEffort` is sent unchanged. On
reasoning models, `temperature` and `topP` are removed with warnings. Chat maps
`max` to the highest supported effort; Responses sends `max` to models that
support it.

### Structured output

JSON schemas are normalized for OpenAI's strict mode. Function tools default to
`strict: false`. For JSON responses, the last `final_answer` message becomes
`structuredOutputText`, while `text` keeps every message, drafts included.

### Prompt caching

`promptCacheOptions` accepts `mode` (`implicit` or `explicit`), `ttl` (`30m` or
`12h`) and `prewarm: true`. A prewarm call can return no text and zero output
tokens. Cache-write totals are reported in `TokenUsage`. A user text part can
set a breakpoint through `providerMetadata["openai"]["promptCacheBreakpoint"]`.

### Interrupted streams

A Chat, Completion or Responses stream that ends without a completion signal
finishes with reason `interrupted`. Keep the partial output and decide whether to
retry; tool execution and automatic continuation stop for that response.

## Hosted tools

`OpenAITools` provides Responses tools, including `webSearch`, `fileSearch`,
`codeInterpreter`, `imageGeneration`, `mcp`, `shell`, `localShell`,
`applyPatch`, `computer`, `toolSearch` and `programmaticToolCalling`.

```swift
let result = try await model.generateText(
    "What changed in the latest Swift release?",
    tools: LanguageToolOptions(rawTools: ["web_search": OpenAITools.webSearch()])
)
print(result.sources)
```

`webSearchPreview` is deprecated; use `webSearch`. Citations are available on
the text content separately from `result.sources`. To limit which tools the model
may call, set `allowedTools` in provider options.

## Embeddings, images, speech and transcription

```swift
let embedder = try provider.embeddingModel("text-embedding-3-small")
let vectors = try await embedder.embedMany(["alpha", "beta"])

let image = try provider.imageModel("gpt-image-1")
let picture = try await image.generateImage("A lighthouse at dusk", size: "1024x1024")

let tts = try provider.speechModel("gpt-4o-mini-tts")
let speech = try await tts.generateSpeech("Hello!", voice: "alloy")
```

- Image edits take `files` and an optional `mask`. Input URLs are downloaded
  through your transport.
- Transcription models include `whisper-1`, `gpt-4o-transcribe` and
  `gpt-4o-transcribe-diarize`. Whisper defaults to `verbose_json`, and diarization
  to `diarized_json`. Shared `timestampGranularities` requests word and segment
  timings, which only `verbose_json` returns. `providerMetadata["openai"]["languages"]`
  lists the detected languages.
- Native streaming transcription: `streamingTranscriptionModel("gpt-transcribe")`,
  also `gpt-live-transcribe` and `gpt-realtime-whisper`. See
  [Transcribe](../../core/transcribe/).

## Decisions, extraction and realtime

- `decisionModel("gpt-6-luna")` uses the native `/decisions` endpoint with
  [`AI.experimentalDecide`](../../core/decide/). It ignores `maxOutputTokens` and
  `reasoning`, with a warning.
- `extractionModel(_:)` extracts typed fields through Responses; see
  [Extract](../../core/extract/).
- `experimentalRealtime("gpt-live-1")` opens an OpenAI Live server WebSocket
  session; see [Realtime](../../core/realtime/). Other realtime model IDs throw.
  Browser WebRTC is not available.

## Files, skills and batch

`files()` uploads, lists, downloads and deletes files; `skills()` manages skills
for the shell tool. `experimentalBatch()` and `batchLanguageModel(_:)` run
Responses Batch jobs. `batchResultDownloads` limits each downloaded result line
to 64 MiB by default. See [Files](../../core/files/) and
[Batch text](../../core/batch-text/).

## Advanced features

### Mid-conversation configuration updates

`providerOptions["openai"]["textFormat"]` sets the initial Responses text format
separately from output parsing. To change settings partway through the history,
insert an empty system message whose `providerMetadata["openai"]` carries
`reasoningEffortUpdate` (`none`, `low`, `medium`, `high`, `xhigh`, `max`),
`textFormatUpdate` or `additionalTools`. It is sent at that position:

```swift
let update = AIMessage(
    role: .system,
    content: [],
    providerMetadata: ["openai": ["reasoningEffortUpdate": "low"]]
)
```

Format and effort updates need GPT-6 or later in standard reasoning mode, without
automatic compaction or `truncation: "auto"`; otherwise they throw before sending.
Updates cannot be in consecutive messages, so put a format change and an effort
change in the same empty message. Non-empty system messages with these keys throw.

### Tools loaded during a conversation

`additionalTools` can also be attached to an ordinary `AIToolResult` through
`providerMetadata: ["openai": ["additionalTools": [...]]]`. The tools are inserted
right after that result. Each definition needs `type: "function"`, a nonempty
`name` and object `parameters`, with optional `description`, `strict` and
`defer_loading`. To keep a function tool local but leave it out of the top-level
tool list, set its `providerOptions.openai.omitFromRequestTools` to `true`. Such a
tool cannot be forced or allow-listed until it appears in history.

### Prompt-cache diagnostics

Set `promptCacheOptions.comparisonResponseId` to an earlier response ID to request
cache comparison diagnostics. Unary, streaming and batch results return the raw
fields in `providerMetadata["openai"]["promptCacheDiagnostics"]`.

### Decision evidence limits

Decisions send JSON objects, and nonempty arrays of objects, as native
`input_json` when they nest at most 32 levels deep, contain at most 10,000 values
and encode to at most 256 KiB of UTF-8. Larger or other values are sent as JSON
text. Image evidence accepts PNG, JPEG, WebP and GIF. `promptCacheKey` is
supported in Decisions provider options.

### GPT Image controls

Image provider options accept `complexity` (`low`, `medium`, `high`),
`safetyIdentifier` (up to 128 characters), `outputFormat`, `outputCompression`,
`inputFidelity` and, for edits, `markup`. Generation can output `gif`, with
`frameCount` (2–64) and `frameDurationMs` (20–2000). Edits reject `gif` output and
ignore frame settings. `markup` can be a base64 data URL or a URL that is
downloaded; it cannot be combined with `mask`. Invalid values throw before the
request is sent. Image files, masks and markup are downloaded through your transport.

### MCP tunnels

`OpenAITools.mcp(serverLabel:..., tunnelID:)` connects through a secure tunnel.
Each MCP tool needs exactly one target: `serverURL`, `connectorID`, or `tunnelID`
alone. Combining `tunnelID` with the others throws.

### Shell output limits

Shell tool calls keep `action.timeoutMs` and `action.maxOutputLength` when OpenAI
returns them, and shell results expose `maxOutputLength`. Replaying history with
`store: false`, or sending a tool result, keeps that limit. Shell calls in container
environments are marked provider-executed; calls for local execution stay client calls.
`OpenAITools.shellAllowlistNetworkPolicy(allowedDomains:domainSecrets:)` and
`shellDisabledNetworkPolicy()` control container network access.

### Telemetry redaction

OpenAI tool credentials, such as MCP authorization, are removed from telemetry
copies. The request and response values returned to your app are unchanged.

## Rotating API keys

To rotate keys, set `OpenAIProviderSettings.apiKeyProvider` to an async throwing
closure and pass it to `AIProviders.openAI(configuration:)`. It runs before every
authenticated request and WebSocket connection, including Files, Skills and Batch.
Explicit authorization headers still take precedence.
