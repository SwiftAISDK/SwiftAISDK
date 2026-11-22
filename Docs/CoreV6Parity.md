# Core V7 Parity

Snapshot date: 2026-11-22

This document tracks SwiftAISDK against the current AI SDK Core and Errors
reference. It is intentionally high-level: product status belongs in
`PortingStatus.md`, provider package drift belongs in `ProviderVersionLedger.md`,
and provider behavior belongs in focused tests.
The current snapshot versions below are generated from `Porting/upstream-lock.json`;
parity explanations remain hand-authored.
Implementation-sensitive UI/chat items are also checked against npm source
snapshots, currently `ai@7.0.179`, `@ai-sdk/provider@4.0.39`, `@ai-sdk/provider-utils@5.0.83`, and `@ai-sdk/react@4.0.183`.

References:

- <https://ai-sdk.dev/docs/reference/ai-sdk-core>
- <https://ai-sdk.dev/docs/reference/ai-sdk-errors>
- <https://ai-sdk.dev/docs/reference/ai-sdk-ui>

Dated core deltas and package diff notes from earlier passes are archived in
[Archive/CoreParityHistory.md](Archive/CoreParityHistory.md).

## Status Labels

| Status | Meaning |
| --- | --- |
| `covered` | SwiftAISDK has a direct product-level API or type for this surface. |
| `swift-native` | The behavior is present, but intentionally shaped differently for Swift. |
| `partial` | Important behavior exists, but the upstream surface is not fully represented. |
| `missing` | No meaningful current equivalent. |
| `out of scope candidate` | Likely frontend, JS-framework, or TS-specific surface; needs an explicit product decision. |

## AI SDK Core Reference

| Upstream reference item | SwiftAISDK status | Current Swift evidence | Notes / next decision |
| --- | --- | --- | --- |
| `generateText` | `covered` | `AI.generateText`, `LanguageModelRequest`, `TextGenerationResult` | Supports prompt/request overloads, tools, multi-step loops, retries, telemetry, provider metadata, response metadata, raw chunks, and abort signals. Later tool-loop steps recheck cancellation before another model call and preserve the caller's abort reason. |
| `streamText` | `covered` | `AI.streamText`, `LanguageStreamPart`, `AIStreamProviderError`, `AIStreamingTransport`, `AIStreamTimeoutConfiguration`, incremental SSE/EventStream and semantic-timeout regressions | Async sequence surface with provider parts delivered before HTTP EOF, one part-aware content lifecycle, one built-in terminal outcome per logical response, typed in-band provider failures, tools, approvals, setup retries plus opt-in isolated post-start recovery for retryable in-band provider errors, telemetry, and total/per-step/first-semantic/inter-semantic deadlines. Total/step budgets include retry backoff, step deadlines span client tool execution, typed `Output` streams share the configuration, and timeout aborts propagate to provider/tool signals. |
| `embed` | `covered` | `AI.embed`, `EmbeddingRequest`, `EmbeddingResult` | Single-value helper delegates through the embedding request shape. |
| `embedMany` | `covered` | `AI.embedMany`, `EmbeddingModel.maxEmbeddingsPerCall`, `EmbeddingModel.maxInputBytesPerCall` | Splits once against the caller/model count limit and provider UTF-8 byte budget, keeps an individually oversized value intact, and aggregates usage/warnings/metadata in request order. |
| `rerank` | `covered` | `AI.rerank`, `RerankingRequest`, `RerankingResult` | Native model family exists. |
| `experimental_evaluate` | `covered` | `AI.experimentalEvaluate`, `AIEvaluationModelV4`, `AIEvaluationProvider`, `AIEvaluationModelReference` | Provider-neutral Choice, Score, and Boolean evaluation validates question/answer contracts, retries transient failures, preserves rounding/usage/warnings/metadata, and resolves direct, registry, or custom-provider models. OpenAI, Anthropic, Google, and Gateway expose adapters. |
| `experimental_extract` | `covered` | `AI.experimentalExtract`, `AIExtractionModelV4`, `AIExtractionModelReference`, `AIExtractionStartEvent`, `AIExtractionEndEvent` | Typed field requests and answers, model aliases and registry routing, empty answer normalization, and redacted native telemetry. Gateway exposes native Extraction V4. |
| `generateImage` | `covered` | `AI.generateImage`, `ImageGenerationRequest`, `ImageGenerationResult.calls` | Includes files, masks, provider options, aggregate metadata, per-call results, warnings, retries, and aborts. True request splitting and provider-specific cost aggregation across multiple calls remain deferred. |
| `transcribe` | `covered` | `AI.transcribe`, `AudioTranscriptionRequest`, `detectMediaType` | Upstream now documents `transcribe`; older experimental naming is intentionally not mirrored. Shared media detection recognizes MP4/M4A from the ISO-BMFF `ftyp` box in an audio context and bounds ID3 scanning. |
| `StreamingTranscriptionModel` | `covered` | `StreamingTranscriptionModel`, `AIStreamingAudioInput`, `StreamingTranscriptionPart`, `CartesiaStreamingTranscriptionModel`, `GatewayTranscriptionModel` | Provider-neutral duplex transcription lifecycle with Cartesia Ink 2 and Gateway adapters. Gateway adds a short-lived route-bound token factory; ElevenLabs realtime STT remains deferred. |
| `generateSpeech` | `covered` | `AI.generateSpeech`, `SpeechRequest` | Native model family exists. |
| `experimental_generateVideo` | `covered` | `AI.generateVideo`, `AI.startVideo`, `AI.getVideoStatus`, `VideoGenerationRequest`, `AsyncVideoModel`, `VideoGenerationPollOptions` | Stable Swift naming preserves unary generation and adds directly persistable V4 start/status, polling, webhook waiting, cancellation, metadata merging, logical-start idempotency, and count splitting. BFL, Fal, ByteDance, and Gateway are vertical adapters; Fal and Gateway support native callback URLs while BFL and ByteDance fall back to polling with a warning. |
| `startTextBatch` / `getBatchStatus` / `getBatchResults` | `covered` | `AI.startTextBatch`, `AI.getBatchStatus`, `AI.getBatchResults`, `BatchLanguageModel` | Durable text batches expose persistable references, optional completion webhooks, normalized status/counts, full result content, and complete per-item terminal streams through Anthropic Messages Batch, OpenAI Responses Batch, Gateway Batch V4, and xAI Responses Batch. Gateway forwards webhooks; the direct providers warn that they are unsupported. |
| Provider-owned Batch structured output | `covered` | `AI.startBatch(output:)`, `AI.getBatchResults(output:)`, `BatchOutputItemResult` | Applies one structured output specification to text requests and keeps each result's text, usage, and output parse status independently. |
| `Experimental_RealtimeModelV4` | `covered` | `AIRealtimeModelV4`, `AIRealtimeSession`, `XAIRealtimeModel`, `OpenAILiveModel`, `GoogleRealtimeModel`, `GatewayRealtimeModel` | Native turn-based and continuous WebSocket lifecycles with normalized audio/text/tool/delegation/usage/error events, aborts and close behavior. Google and Gateway support ephemeral-client and trusted-server connections with per-session parsing and usage snapshots. Browser WebRTC, provider-backed Responses delegation and non-Live OpenAI Realtime remain deferred. |
| `Output` | `covered` | `Output.text/object/array/choice/json`, `AI.generateText(... output:)`, `AI.streamText(... output:)`, existing object-generation facades | Swift now mirrors the v6-style `generateText/streamText + Output.*` entry point while still keeping the older Swift-native object/array/enum/json facades. `Output.object` partial streaming uses `JSONValue` because Swift has no automatic `DeepPartial<T>`. |
| `Agent` interface | `covered` | `AIAgent`, `AIAgentCallOptions` | Swift-native agent protocol mirrors upstream `version: "agent-v1"`, optional `id`, tool exposure, and generate/stream calls over model messages or prompts. |
| `ToolLoopAgent` | `covered` | `AIToolLoopAgent`, tool-loop overloads on `AI.generateText` and `AI.streamText` | Reusable agent object wraps the existing Swift tool loop. Default `maxSteps` is 20 to match upstream `stepCountIs(20)` behavior. |
| `createAgentUIStream` | `partial` | `createAgentUIStream`, `AIUIMessageStreamReducer.snapshots(from:)` | Converts validated `AIUIMessage` history to model messages, streams through any `AIAgent`, and returns assistant UI-message snapshots. Repeated tool-call ids across explicit upstream step boundaries remain deferred until the Swift stream type represents those boundaries. |
| `createAgentUIStreamResponse` | `out of scope candidate` | none | JS response/server surface; likely not a SwiftPM core priority unless a Swift server use case is chosen. |
| `pipeAgentUIStreamToResponse` | `out of scope candidate` | none | Same as above. |
| `tool` | `swift-native` | `AITool` | Swift uses a concrete typed tool struct rather than a TS inference helper. |
| `dynamicTool` | `swift-native` | `AITool.dynamic`, MCP tool conversion | Behavior exists; naming differs. |
| `createMCPClient` | `covered` | `MCPClient.connect`, `MCPHTTPTransport`, `MCPStdioTransport`, `MCPApps` | Broad MCP client, transport, OAuth, resources, prompts, completions, elicitation, MCP Apps metadata/resource helpers, session resume callbacks, initial initialize result reuse, paginated tool discovery, tool-call retries, tool conversion, annotations, structured-only results, issuer normalization, and non-successful POST/SSE diagnostics through `@ai-sdk/mcp@2.0.60`. OAuth scope reaches dynamic registration, preserves pre-registered client credentials on client-auth failures, removes discovery protocol headers across origins, keeps caller-supplied stdio environment values, rejects private credential endpoints without redirects, reuses stored authorization-server metadata after discovery failure, and coalesces concurrent stale-token refreshes. |
| `Experimental_StdioMCPTransport` | `covered` | `MCPStdioTransport` | Swift uses stable transport naming. |
| `jsonSchema` | `swift-native` | `AIJSONSchema`, `JSONValue`, `parseJSON`, schema validator | Usable JSON Schema adapter exists; exact factory naming does not. |
| `zodSchema` | `out of scope candidate` | none | Zod is TypeScript-specific. Could document `AIJSONSchema` as the Swift alternative. |
| `valibotSchema` | `out of scope candidate` | none | Valibot is TypeScript-specific. |
| `ModelMessage` | `covered` | `AIMessage`, `AIContentPart`, `MessageRole`, `convertToLanguageModelPrompt` | Swift naming differs but covers system/user/assistant/tool plus text, file, image URL, provider references, tool calls/results, approvals. Consecutive tool messages preserve message-level provider metadata at each combined-content boundary. |
| `UIMessage` | `covered` | `AIUIMessage`, `AIUIMessagePart`, text/reasoning/data/file/source/tool/approval/custom parts | Swift keeps UI/render messages separate from `AIMessage` model-request messages. |
| `validateUIMessages` | `covered` | `validateUIMessages` | Validates non-empty message arrays/parts, ids, tool JSON arguments, tool-result links, and approval links. Schema-driven metadata/data/tool validation remains Swift-native rather than a direct Zod/Standard Schema port. |
| `safeValidateUIMessages` | `covered` | `safeValidateUIMessages`, `AIUIMessageValidationResult` | Non-throwing validation result for UI persistence/import flows. Swift returns accumulated issues instead of the upstream `{ success, data/error }` union. |
| `createProviderRegistry` | `covered` | `createProviderRegistry`, `AIProviderRegistry` | Registry and default-provider flows exist. |
| `customProvider` | `covered` | `customProvider`, `AICustomProvider` | Supports configured models/clients and fallbacks. |
| `cosineSimilarity` | `covered` | `cosineSimilarity(_:_:)` for `Double` and `Float` vectors | Mirrors upstream empty-vector and zero-magnitude behavior, and throws `AIError.invalidArgument` for mismatched lengths. |
| `wrapLanguageModel` | `covered` | `wrapLanguageModel`, `AILanguageModelMiddleware` | Includes generate/stream wrapping and request transforms. |
| `wrapImageModel` | `covered` | `wrapImageModel`, `AIImageModelMiddleware` | Direct surface exists. |
| `LanguageModelV3Middleware` | `covered` | `AILanguageModelMiddleware` | Swift-specific type name; semantics are similar. |
| `extractReasoningMiddleware` | `covered` | `extractReasoningMiddleware` | Direct helper exists. |
| `simulateStreamingMiddleware` | `covered` | `simulateStreamingMiddleware` | Direct helper exists. |
| `defaultSettingsMiddleware` | `covered` | `defaultSettingsMiddleware` | Direct helper exists. Swift also has embedding defaults. |
| `addToolInputExamplesMiddleware` | `covered` | `addToolInputExamplesMiddleware` | Direct helper exists. |
| `extractJsonMiddleware` | `covered` | `extractJsonMiddleware`, `extractJSONMiddleware` | Direct helper plus Swift capitalization alias. |
| `stepCountIs` | `swift-native` | `AIStopCondition.isStepCount` | Behavior exists; helper name differs. |
| Steering interrupts | `swift-native` | `AISteering.steer(…, interrupt: true)` | A pre-output interrupt replaces an in-flight request within its current logical step. Visible text, tool execution, and streaming step deadlines keep their native lifecycle. |
| `hasToolCall` | `swift-native` | `AIStopCondition.hasToolCall` | Behavior exists; helper name differs. |
| `simulateReadableStream` | `covered` | `simulateReadableStream(chunks:initialDelayNanoseconds:chunkDelayNanoseconds:)` | Swift-native `AsyncThrowingStream` equivalent with `nil` delays as the no-delay path. |
| `smoothStream` | `covered` | `smoothStream(_:delayNanoseconds:chunking:)`, custom detector overload | Smooths text/reasoning deltas by word, line, or custom detector; flushes before non-text chunks and preserves metadata. |
| `generateId` | `covered` | `generateId()` | Public 16-character non-secure ID helper matching upstream default length/alphabet. |
| `createIdGenerator` | `covered` | `createIdGenerator(prefix:separator:size:alphabet:)` | Supports prefix, separator, size, and alphabet. Separator is only used when `prefix` is provided, matching upstream provider-utils behavior. |
| `DefaultGeneratedFile` | `missing` | `AIStreamFile`, generated media result structs | File/media objects exist, but not the upstream named type. |

## AI SDK Errors Reference

SwiftAISDK currently favors fewer stable Swift error types instead of one public
error class per upstream `AI_*` error. That gives a simpler Swift surface, but
it means JavaScript-style error-class parity is only partial.

| Upstream error | SwiftAISDK status | Current Swift evidence | Notes / next decision |
| --- | --- | --- | --- |
| `AI_APICallError` | `covered` | `AIAPICallError`, `AIError.apiCallError`, provider-specific HTTP error mapping | Swift keeps existing `AIError.httpStatus*` compatibility while exposing a richer API-call error shape for status/body/headers/retryability diagnostics. |
| `AI_DownloadError` | `covered` | `AIDownloadError` | Direct Swift analog exists. |
| `AI_EmptyResponseBodyError` | `partial` | `AIError.invalidResponse` | Empty-body cases are reported through general invalid-response errors. |
| `AI_InvalidArgumentError` | `covered` | `AIError.invalidArgument` | Direct functional analog exists. |
| `AI_InvalidDataContentError` | `partial` | `AIError.invalidArgument`, `AIDownloadError`, media validation paths | No dedicated public type. |
| `AI_InvalidMessageRoleError` | `partial` | `MessageRole` enum, provider message conversion validation | Swift enum prevents many invalid roles, but conversion failures use general errors. |
| `AI_InvalidPromptError` | `partial` | `AIError.invalidArgument`, provider conversion errors | No dedicated prompt error with structured prompt details. |
| `AI_InvalidResponseDataError` | `covered` | `AIError.invalidResponse` | Functional analog exists, though less structured. |
| `AI_InvalidToolApprovalError` | `covered` | `AIInvalidToolApprovalError`, `validateUIMessages` | Throwing UI-message validation now reports unknown approval response ids with a typed approval error; `safeValidateUIMessages` still returns accumulated issues. |
| `AI_InvalidToolInputError` | `covered` | `AIInvalidToolInputError`, `AITypeValidationError`, `AITool` validation/refinement | New tool argument JSON/schema failures throw typed tool-input errors. Invalid persisted approved calls become model-visible error results and continue without executing the tool. |
| `AI_JSONParseError` | `covered` | `AIJSONParseError` | Direct Swift analog exists. |
| `AI_LoadAPIKeyError` | `covered` | `AIError.missingAPIKey` | Functional analog exists. |
| `AI_LoadSettingError` | `partial` | `AIError.invalidArgument`, provider settings validation | No dedicated setting-load error. |
| `AI_MessageConversionError` | `partial` | provider-specific conversion errors via `AIError.invalidArgument`/warnings | No dedicated public message-conversion error. |
| `AI_NoContentGeneratedError` | `covered` | `AINoContentGeneratedError` | Public cross-modal no-content analog exists for callers that want the generic upstream error concept. |
| `AI_NoImageGeneratedError` | `covered` | `AINoImageGeneratedError`, `AI.generateImage` | The public facade throws a typed error when a successful image model call returns no URL or base64 image. Provider-specific low-level models may still throw narrower invalid-response errors before returning. |
| `AI_NoTranscriptGeneratedError` | `covered` | `AINoTranscriptGeneratedError`, `AI.transcribe` | The public facade throws a typed error for empty final transcript text. |
| `AI_NoVideoGeneratedError` | `covered` | `AINoVideoGeneratedError`, `AI.generateVideo` | The public facade throws a typed error when no URL or base64 video is returned. |
| `AI_NoSpeechGeneratedError` | `covered` | `AINoSpeechGeneratedError`, `AI.generateSpeech` | The public facade throws a typed error for empty generated audio. |
| `AI_NoObjectGeneratedError` | `covered` | `AIObjectGenerationError` with `kind` and `strategy` | Swift groups object/array/enum/json failures into one typed error. |
| `AI_NoOutputGeneratedError` | `covered` | `AINoOutputGeneratedError`, `AIObjectGenerationError` | The v6-style `Output` stream mapper now has a dedicated no-output error for streams that finish without final output. Object parsing still uses `AIObjectGenerationError` for invalid generated output. |
| `AI_NoSuchModelError` | `covered` | `AIError.unsupportedModel` | Functional analog exists. |
| `AI_NoSuchProviderError` | `covered` | `AIProviderRegistryError.noSuchProvider` | Direct registry analog exists. |
| `AI_NoSuchToolError` | `covered` | `AINoSuchToolError` | Local tool loops now throw a typed error when the model asks for an unavailable non-provider-executed tool. |
| `AI_RetryError` | `covered` | `AIRetryError`, `AIRetryErrorReason` | Direct Swift analog exists. |
| `AI_StreamProviderError` | `covered` | `AIStreamProviderError`, `LanguageStreamPart.providerError`, `LanguageStreamPart.streamProviderError` | Public typed view of an in-band provider failure, preserving the provider's message, type, string/numeric code, HTTP status, retryability, and raw payload while retaining the source-compatible stream error case. |
| `AI_ToolCallNotFoundForApprovalError` | `covered` | `AIToolCallNotFoundForApprovalError`, `validateUIMessages` | Approval requests that reference a missing tool call now surface as a typed error in throwing validation. |
| `AI_ToolCallRepairError` / `ToolCallRepairError` | `covered` | `AIToolCallRepairError`, `AITool.refineArguments` | Swift maps the existing argument-refinement hook to a typed tool-call repair failure. |
| `AI_TooManyEmbeddingValuesForCallError` | `covered` | `AITooManyEmbeddingValuesForCallError`, embedding model preflight guards | OpenAI-compatible, Google, Google Vertex, Voyage, Mistral, Cohere, and Amazon Bedrock embedding limits now throw a typed error carrying provider, model id, max count, and values. |
| `AI_TypeValidationError` | `covered` | `AITypeValidationError`, `AIJSONSchemaValidator`, `AIObjectGenerationError.kind == .schemaValidation` | Schema validation now has a standalone public type-validation error, while object generation continues to wrap schema failures in `AIObjectGenerationError`. |
| `AI_UIMessageStreamError` | `covered` | `AIUIMessageStreamError` | Used for UI message validation and stream-reduction failures. Carries `chunkType`/`chunkID` for out-of-sequence stream chunks, plus Swift validation issues. |
| `AI_UnsupportedFunctionalityError` | `partial` | `AIError.unsupportedModel`, `AIWarning(type: "unsupported", ...)`, provider invalid-argument paths | Unsupported features are represented, but not as a dedicated public error class. |

## Recommended Next Passes

1. Decide how explicit model-step boundaries should enter
   `LanguageStreamPart`, then scope `AIUIMessageStreamReducer` tool lookup to
   the current step while retaining backwards lookup for late tool outputs.
2. Continue polishing the new `AIOutput` surface where it proves useful:
   document examples and consider array `elementStream` ergonomics. The
   `choice/json` factories already propagate `name` and `description` as
   provider hints.
3. Decide whether `DefaultGeneratedFile` deserves a named Swift analog or
   whether `AIStreamFile` plus generated media result structs are sufficient.
4. Keep JS response helpers (`createAgentUIStreamResponse`,
   `pipeAgentUIStreamToResponse`, `createUIMessageStreamResponse`,
   `pipeUIMessageStreamToResponse`) out of core unless SwiftAISDK grows a
   server-side Swift target.
5. Continue typed-error parity only where it improves Swift diagnostics. The
   middle-path batches now cover API calls, type validation, no-output,
   no-such-tool, invalid tool input, tool-call repair, approval-link failures,
   no-generated media, and too-many embedding values. Remaining candidates are
   mostly prompt/message conversion and narrower provider response-shape errors.

## SwiftUI UI Layer Candidates

The AI SDK UI reference is web-framework oriented, but several ideas map well
to SwiftUI. These are not intended as direct ports of React/Svelte/Vue hooks;
they are candidate Swift-native product surfaces for a future SwiftUI layer.

| Upstream UI idea | SwiftUI candidate | Priority | Notes |
| --- | --- | --- | --- |
| `useChat` | `AIChatSession` | done | Combine-backed `ObservableObject` for iOS 15/macOS 12+ that manages `messages`, `status`, `error`, `sendMessage`, submit-existing-transcript, replacement, `regenerate`, `stop`, `resumeStream`, `addToolOutput`, and `addToolApprovalResponse` over `AIChatTransport`. Uses upstream status names and mirrors `onError`, `onFinish`, abort/resume finish semantics, and `sendAutomaticallyWhen`. Swift tool output currently appends tool-role messages instead of mutating stateful upstream tool UI parts. |
| `UIMessage` and message parts | `AIUIMessage`, `AIUIMessagePart`, metadata/data parts | done | Core render-message model exists without depending on SwiftUI/Observation. |
| `convertToModelMessages` | `convertToModelMessages` | done | Converts supported `AIUIMessage` parts into `AIMessage` history for model calls; render-only parts are ignored, unsupported URL files fail with `AIUIMessageStreamError`. |
| `readUIMessageStream` / UI stream reducer | `AIUIMessageStreamReducer` | partial | Converts `LanguageStreamPart` into stable UI message snapshots, so UI layers do not hand-roll streaming assembly. ID-based text/reasoning/tool-input chunks reject missing starts like upstream `processUIMessageStream`; Swift keeps id-less language deltas as a compatibility convenience. Repeated tool-call ids across model steps remain deferred because the stream enum does not yet expose step boundaries. |
| `useObject` | `AIObjectGenerationSession<Output, Partial>` | done | Combine-backed `ObservableObject` over v6-style `Output` streaming with `partialObject`, final `object`, `result`, status, error, text, warnings, metadata, `submit`, `stop`, and `clear`. Final object validation errors are reported through `onFinish`, matching upstream `useObject` semantics. |
| `DirectChatTransport` | `AIChatTransport`, `AIChatTransportRequest`, `AIChatRequestOptions`, `DirectAIChatTransport` | done | In-process transport streams `AIUIMessage` snapshots from `AI.streamText`, supports tool-loop options, request defaults, aborts, retry/timeout/telemetry, and reasoning/source/finish filters. Leave room for an `HTTPChatTransport` later when an app talks to its own backend. |

### Not Worth Directly Porting

| Upstream UI idea | Decision | Reason |
| --- | --- | --- |
| `useCompletion` | `defer` | Most SwiftUI completion use cases can be handled by a small view model over `streamText`; add only if repeated app code proves the need. |
| `createUIMessageStreamResponse` | `out of scope candidate` | Web response helper; not useful for local SwiftUI unless SwiftAISDK grows a server-side Swift story. |
| `pipeUIMessageStreamToResponse` | `out of scope candidate` | Node/server response helper; same rationale as above. |
| `InferUITools` / `InferUITool` | `out of scope` | TypeScript inference helpers with no direct Swift equivalent. |

### Suggested Build Order

1. Add examples/docs for `AIObjectGenerationSession` and agent UI streams once the public naming settles.
2. Consider `useCompletion` only if real SwiftUI app code repeatedly needs a dedicated completion session.
