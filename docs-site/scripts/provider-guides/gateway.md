## Quick start

```swift
import SwiftAISDK

let gateway = try AIProviders.gateway()
let model = try gateway.languageModel("openai/gpt-4.1-mini")
let result = try await model.generateText("Give me three names for a coffee shop.")
print(result.text)
```

`AIProviders.gateway(settings:teamIDOrSlug:)` returns the native `GatewayProvider`.
For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIGateway`
with `AIProviders.gateway(configuration: GatewayProviderSettings())`. The native
factory requires the configuration argument and accepts an optional
`teamIDOrSlug`; rotating credentials need the native settings.

Model IDs are open `creator/model` strings, so models that Gateway adds later
work without an SDK update.

## Authentication and teams

The provider uses, in order: an explicit `apiKey`, `AI_GATEWAY_API_KEY`, then
`VERCEL_OIDC_TOKEN`. An empty key falls through to OIDC; a non-empty invalid key
stays selected. The OIDC token is read again for each request, so a refreshed
token is picked up automatically. Requests go to `https://ai-gateway.vercel.sh/v4/ai`
unless you set `baseURL`.

Pass `teamIDOrSlug` to scope requests to a team:

```swift
let gateway = try AIProviders.gateway(teamIDOrSlug: "my-team")
```

## Models

| Factory | Use with |
| --- | --- |
| `languageModel(_:)` | [Generate text](../../core/generate-text/), [Stream text](../../core/stream-text/) |
| `embeddingModel(_:)` | [Embeddings](../../core/embeddings/) |
| `imageModel(_:)` | [Generate image](../../core/generate-image/) |
| `videoModel(_:)` | [Generate video](../../core/generate-video/) |
| `speechModel(_:)`, `streamingSpeechModel(_:)` | [Generate speech](../../core/generate-speech/), [Stream speech](../../core/stream-speech/) |
| `transcriptionModel(_:)`, `streamingTranscriptionModel(_:)` | [Transcribe](../../core/transcribe/) |
| `rerankingModel(_:)` | [Rerank](../../core/rerank/) |
| `decisionModel(_:)`, `evaluationModel(_:)` | [Decide](../../core/decide/), [Evaluate](../../core/evaluate/) |
| `extractionModel(_:)`, `extraction(_:)` | [Extract fields](../../core/extract/) |
| `experimentalRealtime(_:api:)`, `realtimeModel(_:)`, `liveModel(_:)` | [Realtime](../../core/realtime/) |
| `experimentalBatch()` | [Batch text](../../core/batch-text/) |

## Routing options

Gateway options go under `providerOptions["gateway"]` and are forwarded as-is:

```swift
let result = try await model.generateText(
    "Summarize this contract.",
    options: LanguageGenerationOptions(providerOptions: [
        "gateway": [
            "order": ["openai", "anthropic"],
            "models": ["anthropic/claude-opus-5-fast"],
            "sort": "ttft",
            "has": ["implicit-caching", "vision"],
            "disallowPromptTraining": true,
            "serviceTier": "flex",
            "tags": ["contracts"],
        ],
    ])
)
```

These cover provider order and fallback models, provider allow-lists, BYOK
credentials, prompt-training restrictions, capability (`has`) filters, sort order,
service tier, quota attribution and tags. `GatewayProviderOptions` builds
headquarters restrictions with type safety; prefix a country code with `!` to
exclude it:

```swift
let options = GatewayProviderOptions(
    headquarters: ["US", "DE"],
    additionalOptions: ["order": ["openai"]]
).providerOptions
```

Structured Gateway errors keep their type, status, retryability, `retryAfter`
and extra fields.

## Gateway tools

`GatewayTools` creates tools that Gateway executes on the server:
`parallelSearch`, `perplexitySearch`, `exaSearch`, `takoSearch`, `browserbaseSearch`,
`browserbaseFetch`, `deepseekSearch` and `deepseekFetch`. Pass them as provider
tools in the request:

```swift
let search = GatewayTools.parallelSearch(
    mode: "fast",
    includeDomains: ["docs.python.org/3"],
    maxCharsTotal: 8_000,
    maxAgeSeconds: 600
)
let result = try await model.generate(LanguageModelRequest(
    messages: [.user("What changed in the latest Python release?")],
    tools: ["search": search]
))
```

- Parallel Search modes: `turbo`, `fast`, `basic` (server default) and
  `advanced`, plus the legacy `one-shot` and `agentic`. Domain filters may include
  paths. `timeoutSeconds` and `disableCacheFallback` control fetch freshness; cache
  ages below 600 seconds are raised to 600. Results keep the raw snake_case
  fields (`search_id`, `results[].excerpts`, `session_id`).
- `takoSearch(GatewayTakoSearchConfig(...))` accepts effort, data and web sources,
  location and locale. The developer controls `variableCost`, `maxVariableCostUSD`
  (`.null` removes the cap) and `extraBody` are set with
  `GatewayTakoSearchConfig(variableCost:maxVariableCostUSD:extraBody:)`.

## Speech and transcription

Speech models can stream through `AI.experimentalStreamSpeech`:

```swift
let speech = try gateway.streamingSpeechModel("elevenlabs/eleven-flash-v2.5")
```

Transcription supports unary requests and a duplex WebSocket stream. The shared
`timestampGranularities` option is not forwarded and produces a warning; word
timings are returned separately when the model reports them.

### Client tokens

On a trusted server, mint a short-lived, model-bound token for a client instead of
sharing your key. Lifetimes default to 60 seconds and are capped at 300.

```swift
let speechToken = try await gateway.experimentalSpeech.getToken(.init(
    model: "elevenlabs/eleven-flash-v2.5",
    expiresAfterSeconds: 60
))
let transcriptionToken = try await gateway.experimentalTranscription.getToken(.init(
    model: "openai/gpt-realtime-whisper"
))
print(speechToken.token, speechToken.url, speechToken.expiresAt ?? 0)
```

`gateway.experimentalTranscription("openai/gpt-realtime-whisper")` also creates a
streaming transcription model directly.

Clients that open their own WebSocket carry the token in subprotocols:
`GatewayRealtimeAuth.realtimeProtocols(token:teamIDOrSlug:)` (and the `speech` and
`transcription` variants) build them, and a compatible server reads them back with
`GatewayRealtimeAuth.authToken(fromSecWebSocketProtocol:)` and
`teamIDOrSlug(fromSecWebSocketProtocol:)`.

## Realtime and Live conversations

`gateway.experimentalRealtime("openai/gpt-live-1.1")` selects the continuous
Live route. `openai/gpt-live-1` also selects Live. Other IDs default to the
turn-based realtime route. Pass `api: .live` for a new Live ID or
`api: .realtime` to force the turn-based route. Use `liveModel(_:)` and
`realtimeModel(_:)` when you want a concrete model for a particular route.

```swift
let live = gateway.experimentalRealtime("openai/gpt-live-1.1")
let token = try await gateway.experimentalRealtime.getToken(.init(
    model: "openai/gpt-live-1.1",
    expiresAfterSeconds: 60
))
let format = AIRealtimeAudioFormat(type: "audio/pcm", rate: 24_000)
let session = try await AIRealtimeSession.connect(
    model: live,
    clientSecret: token,
    sessionConfiguration: .init(inputAudioFormat: format, outputAudioFormat: format)
)
```

Mint client tokens on a trusted process. Live tokens bind to `/live-model` and
use the same auth and team subprotocols as realtime. For a trusted process that
connects with its own credential, call `AIRealtimeSession.connectServer`.

Live uses `session-start` to open one continuous conversation and `session-close`
to report final usage before closing. After the session emits `sessionStarted`,
stream audio with `appendAudio`, mute or unmute input, and add context with
`appendContext`. Live accepts matching audio
formats on input and output: PCM at 16 or 24 kHz, or PCMA or PCMU at 8 kHz. The
session accepts instructions, voice, audio formats and provider options. For
OpenAI, `delegation` accepts `{"type":"client"}` or JSON null, `input` accepts
up to 128 text messages, `store` accepts a Boolean, and `voice` accepts an object
with a nonempty `id`. `appendContext` accepts `openai.channel` values
`commentary`, `instructions` and `thinking`.

## Video, images and batches

- Video supports asynchronous start/status operations and callback registration
  through the shared facade. Completed videos may be returned as `uploadedVideos`
  without URLs or inline bytes.
- Image results are buffered base64. The `experimental_streamingImageDecoding`
  option is removed from the request, with a warning when it is `true`.
- Batches accept text requests for one common model. Result rows are limited to
  64 MiB each by default; change it with
  `GatewayProviderSettings(batchResultDownloads: AIBatchResultDownloadSettings(maxLineBytes:))`.
  Oversized rows fail with `AIDownloadError`.

## Decisions

```swift
let result = try await AI.experimentalDecide(
    model: try gateway.decisionModel("openai/gpt-6-luna"),
    state: .text("The package arrived cracked."),
    questions: ["damaged": .boolean(instructions: "Is the package damaged?")]
)
```

Decision calls forward `maxOutputTokens` and `reasoning` only when you set them.
Evaluation models use the same decision endpoint and report the model that
actually answered.

## Extraction

```swift
let result = try await AI.experimentalExtract(
    model: gateway.extractionModel("scaledown/extract-1"),
    state: .text("Invoice INV-2041 from Acme Corp. Contacts: Ana, Bo."),
    fields: [
        "invoiceNumber": .init(type: .text, instructions: "The invoice number"),
        "contacts": .init(type: .list, instructions: "Contact names", items: .text),
    ]
)
print(result.answers["invoiceNumber"]?.value?.stringValue ?? "")
```

Gateway sends ordered text, JSON and file state. Send inline files as bytes or
base64. To use file URLs, pass a `download` callback to `AI.experimentalExtract`
so it can prepare the file first. Gateway references are forwarded to the server,
which currently rejects them.

Supported field types depend on the selected model. An unsupported type returns
`AIExtractionUnsupportedFieldTypeError` with the field ID and `fieldTypeLabel`,
which can include the list item type (for example, `list<number>`). Extraction
forwards `referenceDate`, `maxOutputTokens`, `reasoning` and `providerOptions`
when provided. The result includes typed answers, available metadata and warnings.

## Account APIs

- `availableModels()` lists the model catalog, including `description` and
  `pricing` when Gateway publishes them. Entries with an unknown `modelType` are
  skipped. The catalog is cached for `metadataCacheRefreshMillis` (five minutes by
  default); after that a refresh starts while the cached catalog is returned.
- `credits()` returns balance and total usage.
- `getSpendReport(GatewaySpendReportParams(startDate:endDate:))` returns spend
  rows, optionally grouped and filtered by model, provider, user or tags.
- `getGenerationInfo(id:)` returns cost (including market, surcharge and gateway
  cost), latency and token details for one generation.

## Rotating credentials and cancellation

`GatewayProviderSettings(apiKeyProvider:)` takes an async throwing closure that is
called before each authenticated request, streaming speech or transcription
connection, and Live server connection. It must return a non-empty key. An
empty key stops the request with a Gateway authentication error
("No authentication provided").

## Errors and observability

Authentication failures carry Gateway's guidance for the credential in use (API
key or OIDC token). Network failures become a retryable `GatewayError` of type
`responseError` (status 500) whose message starts with
`Invalid error response format: Gateway request failed:`. On Vercel, model
requests forward `VERCEL_DEPLOYMENT_ID`, `VERCEL_ENV`, `VERCEL_REGION` and
`VERCEL_PROJECT_ID` as `ai-o11y-*` headers; the per-request ID from Vercel's
Node request context is not available in Swift.

For access-policy denials, `GatewayError.isAccessPolicyDenied` identifies the
`access_policy_denied` discriminator. The error reports HTTP 403 and can include
`policyIDs`, `removedModels` and `removedProviders`. `GatewayError.description`
includes the generation ID when Gateway returns it.

Task cancellation, `AIAbortError` and timeouts retain their native identity.
