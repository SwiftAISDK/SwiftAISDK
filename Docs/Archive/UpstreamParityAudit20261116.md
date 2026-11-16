# Upstream Behavior Parity Audit (2026-11-16)

Service record of the 2026-11-16 audit. Each provider group was compared with its
reviewed npm package (`Porting/upstream-lock.json`) and matching-release upstream
tests. Divergences were fixed in the owning package with translated upstream tests;
items marked reported were left open and are summarized in `Docs/PortingStatus.md`.
Follow-up work in the same pass: upstream `generateImage` call splitting
(`maxImagesPerCall`) in core; tool metadata stripped from wire parameter schemas in
every provider (`aiFunctionToolInputSchema`); umbrella factories aligned with the
native packages; 22 root compatibility tests updated where they encoded old
behavior. Paths below such as `upstream-all/pkg/<slug>/npm/src/...` refer to the
published npm source and `repo-src/...` to the monorepo test ref.

## Core: ai and react

## Parity audit: core-ai (`ai` → swift-ai-core/SwiftAI, `@ai-sdk/react` → swift-ai-ui)

Baselines: `ai@7.0.173`, `@ai-sdk/react@4.0.177`. Upstream paths below are relative to
`scratchpad/upstream-all/pkg/<slug>/npm/src` (source) or `repo-src` (tests).

### Coverage honesty

- `ai`: 216 test files, ~4,076 `it`/`test` cases. Most existing Swift translations live in the
  root compatibility suite (`Tests/SwiftAISDKTests/Ai*UpstreamTests.swift`, 503 `@Test`s), which
  this group may not edit; `Packages/swift-ai-core/Tests/SwiftAITests` held 11 files.
  A full per-case map of all 4,076 cases was NOT achieved. Reviewed in depth (source + tests vs Swift):
  retry/backoff (`util/retry-with-exponential-backoff`, provider-utils retry), `embed`/`embedMany`,
  `rerank`, `generateImage` (splitting), `generateSpeech` media type, generateText step loop
  (continuation, finish-reason gating, result getters, totalUsage), stop conditions + ToolLoopAgent
  default stop, `toResponseMessages`, `Output` parse gating, UI `convertToModelMessages`,
  `Chat.regenerate`.
- Per-file counts for reviewed files: embed-many 43 (Swift before: ~1 combined test; new: 5),
  embed 28 (1 combined), rerank 32 (6 root; new: 5 incl. 3 parameterized index cases),
  to-response-messages 29 (9 root; new: 1 + 1 loop-level), convert-to-model-messages 77 (16 in UI
  package; new: 5), retry-with-exponential-backoff 15 (15 root, all present).
- NOT reviewed (explicit): stream-text.ts part sequences/callbacks/minimal retention/timeouts beyond
  shared helpers; generate-object/stream-object; middleware family; prompt standardization and
  convert-to-language-model-prompt; tool-call repair/parse; prune-messages; telemetry/tracing;
  realtime; decide/extract/batch; upload-file/skill; generate-video; ui-message-stream family;
  process-ui-message-stream; chat.ts beyond regenerate; http/direct/websocket chat transports;
  react hooks (platform-only by brief); smoothStream (lives in SwiftAIProviderUtilities, other owner).

### Divergences

#### Fixed

1. Retry reason ordering — upstream `provider-utils/src/retry-with-exponential-backoff.ts:101`
   checks `tryNumber > maxRetries` before `shouldRetry`; Swift `Sources/SwiftAI/AIRetryRuntime.swift:31`
   checked retryability first. Effect: after exhausting retries, a final non-retryable error now
   yields `AIRetryError.reason == .maxRetriesExceeded` (was `.errorNotRetryable`). Verdict: fixed.
2. Retry header precedence/parsing — upstream `ai/src/util/retry-with-exponential-backoff.ts:28-45`
   lets any `parseFloat`-numeric `retry-after-ms` suppress `retry-after` (even negative/huge →
   exponential) and uses `parseFloat` prefix parsing. Swift fell back to `retry-after` when
   `retry-after-ms` was negative and rejected values like `1500ms`. Fixed in
   `AIRetryRuntime.swift:532-545` + `leadingDecimalNumber` (`:596`). Effect: retry delay chosen
   from the same header as upstream.
3. embedMany provider metadata merge — upstream `embed/embed-many.ts:450` shallow-merges each
   provider's object across chunks (`{first:true, second:true}`); Swift replaced the whole provider
   entry with the last chunk. Fixed `Sources/SwiftAI/AIFacadeMedia.swift:171`. Effect: chunked
   embedMany no longer loses earlier chunks' metadata keys.
4. embedMany telemetry operation id — upstream always reports `ai.embedMany`
   (`embed-many.ts:211,310`); Swift's single-chunk path delegated to `embed`, which reported
   `ai.embed` for one value. Fixed via `embedSingleCall` (`AIFacadeMedia.swift:22,121`).
5. rerank empty documents — upstream `rerank/rerank.ts:177` returns an empty ranking (callbacks
   fire, no `doRerank`); Swift sent an empty request to the provider. Fixed `AIFacadeMedia.swift:452`.
6. rerank response defaults — upstream `rerank.ts:335,354` defaults `modelId` to the model id and
   `timestamp` to now; Swift left them nil. Fixed `AIFacadeMedia.swift:471`. Invalid-index message
   now prints `between 0 and N-1` exactly (Swift clamped at 0).
7. Empty reasoning dropped from response messages — upstream `generate-text/to-response-messages.ts:66`
   keeps every reasoning part; Swift `Sources/SwiftAI/ResponseMessages.swift` skipped reasoning with
   empty text even when it carried provider metadata. Effect (high): in multi-step tool loops and
   `responseMessages`, encrypted/redacted reasoning with an empty summary (OpenAI Responses
   `itemId`/`reasoningEncryptedContent`, Anthropic/Bedrock redacted thinking) was not replayed to
   the next step. Fixed (skip removed).
8. Same drop in UI conversion — upstream `ui/convert-to-model-messages.ts:228` pushes every reasoning
   UI part; Swift `Packages/swift-ai-ui/Sources/SwiftAIUI/AIUIMessageConversion.swift:147` required
   non-empty text. Fixed.
9. Assistant reasoning-file UI parts dropped — upstream `convert-to-model-messages.ts:221` converts
   them to `reasoning-file` content; Swift ignored `.reasoningFile`. Fixed `AIUIMessageConversion.swift:178`.
10. Non-image data-URL file parts rejected — upstream keeps the URL as a file part that prompt
   conversion inlines; Swift threw "URL files can only be converted…". Swift now decodes RFC 2397
   `data:` URLs into inline `.file` parts (`AIUIMessageConversion.swift:293,318`); remote non-image
   URLs still throw (see reported #R6).

#### Reported, not fixed (outside ownership or needs public API/architecture change)

- R1 generateImage request splitting — upstream `generate-image.ts:188` splits `n` by
  `maxImagesPerCall ?? model.maxImagesPerCall ?? 1` and calls in parallel; Swift `ImageModel`
  (SwiftAIProvider, other owner) has no `maxImagesPerCall`, so the facade sends `count` in one call.
  Documented as deferred in `Docs/CoreV6Parity.md` but not platform-required.
- R2 embedMany parallelism — upstream `embed-many.ts:360` runs chunks concurrently
  (`supportsParallelCalls`, `maxParallelCalls`, default Infinity); Swift is sequential and
  `EmbeddingModel` has no `supportsParallelCalls` (SwiftAIProvider). Latency only; order preserved.
  Also upstream with no limits calls `doEmbed` with `[]` for empty values; Swift returns without a call.
- R3 Retry error text/backoff cap (SwiftAIProvider `Core.swift:53-63,77`): messages differ
  (`attempt(s)`, no quoted error) from upstream `Failed after N attempts. Last error: …` /
  `…with non-retryable error: '…'`; `AIRetryPolicy.maxDelayNanoseconds` caps exponential backoff
  at 60 s, upstream has no cap (only matters with >5 retries). Not documented.
- R4 Deferred provider-executed tool results — upstream `generate-text.ts:963-1010,1608-1634`
  continues the loop while `supportsDeferredResults` provider tool calls are pending; Swift has no
  `supportsDeferredResults` on tools and stops when no client calls remain. Needs tool metadata in
  provider/core types.
- R5 No step-boundary UI parts — upstream inserts `step-start` parts and
  `convertToModelMessages` splits assistant blocks at them, producing
  `[assistant(text1, call), tool(result), assistant(text2)]`; Swift merges a multi-step assistant
  message into `[assistant(text1, call, text2), tool(result)]`, so the model sees later-step text
  before the tool result. Documented deferred in CoreV6Parity ("step boundaries"); needs a
  `LanguageStreamPart` step-boundary case (SwiftAIProvider).
- R6 Remote non-image file URLs in UI conversion throw; upstream passes the URL (downloaded later
  if the model lacks URL support). `AIContentPart` has no file-URL case (SwiftAIProvider). Documented.
- R7 AIChatSession (UI) state differences: appends an empty assistant placeholder at submit
  (upstream adds the assistant message on the first chunk); tool outputs appended as tool-role
  messages instead of mutating tool UI parts (documented); `regenerate()` without id targets the
  last user/assistant message (upstream: last message of any role), passes `messageID: target.id`
  (upstream passes `undefined`), and uses a different error text than upstream
  `message <id> not found`. Architecture-level; left as reported.
- R8 UI conversion still drops empty assistant/user text parts without metadata (upstream keeps
  them); low impact, not changed.

#### Platform-only / matches
- React hooks (`use-chat`, `use-completion`, `use-object`, `use-realtime`) are platform-only.
- Swift tool-loop overloads default `maxSteps: 5` with explicit executable tools (Swift-native API
  shape; upstream `generateText` default `isStepCount(1)`); `AIToolLoopAgent` matches upstream 20 +
  default-stop warning.
- Verified matching: usage summation (`addLanguageModelUsage` incl. raw rule), finish-reason gating
  of tool execution, result getters (text/reasoning from final step, content from all steps),
  Output parse gating, stop conditions, retry defaults (2 retries, 2 s, ×2), retry-after
  reasonableness rule, speech media-type resolution, embedding dimension/count validation.

### Files changed
- Packages/swift-ai-core/Sources/SwiftAI/AIRetryRuntime.swift
- Packages/swift-ai-core/Sources/SwiftAI/AIFacadeMedia.swift
- Packages/swift-ai-core/Sources/SwiftAI/ResponseMessages.swift
- Packages/swift-ai-core/Tests/SwiftAITests/AiCoreParity20261116Tests.swift (new)
- Packages/swift-ai-core/Porting/map.json (registered new test)
- Packages/swift-ai-ui/Sources/SwiftAIUI/AIUIMessageConversion.swift
- Packages/swift-ai-ui/Tests/SwiftAIUITests/AiUIParity20261116Tests.swift (new)
- Packages/swift-ai-ui/Porting/map.json (registered new test)

### Test results
- `swift test --package-path Packages/swift-ai-core --scratch-path .build/agent-core-ai --no-parallel`:
  all passed — 84 + 107 + 49 + 7 = 247 Swift Testing tests (SwiftAITests suite includes 15 new
  test functions / 19 cases).
- `swift test --package-path Packages/swift-ai-ui --scratch-path .build/agent-core-ai-ui --no-parallel`:
  116 passed (5 new).
- Root compatibility suite (`node Scripts/sdk.mjs dev test …`) could NOT run: workspace preparation
  fails with `Unowned workspace input Packages/swift-ai-baseten/Tests/SwiftAIBasetenTests/BasetenUpstreamParityTests.swift`
  (another agent's unregistered file). The reasoning-replay change (#7/#8) should be re-checked
  against the root suite once that is resolved.

## Core: provider and provider-utils

## Parity audit: core-provider (`@ai-sdk/provider@4.0.38`, `@ai-sdk/provider-utils@5.0.81`)

Swift package: `Packages/swift-ai-core`. Scope: the `SwiftAIProvider`, `SwiftAIProviderUtilities` and `SwiftAITransport` modules and their tests. I did not touch `Sources/SwiftAI` or `Tests/SwiftAITests`, which another agent owns.

Upstream sources were read from `.../upstream-all/pkg/{provider,provider-utils}/repo-src` (npm `src` matches).

`U` below means `.../upstream-all/pkg/provider-utils/repo-src`.

### Summary of fixes

| # | Divergence | Upstream evidence | Swift evidence (before → after) | User-visible effect |
|---|---|---|---|---|
| 1 | `isURLSupported` treated every non-wildcard key as a prefix, so `image/png` matched `image/png+invalid`, `image/png;x` and `image/png-not-supported`; it also removed every `*` instead of only the first one. | `U/is-url-supported.ts:28-48` (`mediaTypePrefix.endsWith('/') ? startsWith : ===`, `replace(/\*/, '')`); `U/is-url-supported.test.ts:19-30` | `Sources/SwiftAIProvider/CoreProtocols.swift:16-50` | A provider that declares one exact media type no longer passes URLs of a longer or parameterized media type through natively. Those URLs are now downloaded and inlined, as upstream does. **Fixed.** |
| 2 | `secureJSONParse` used Foundation `JSONDecoder`. That decoder accepts trailing commas (`[1,]`, `{"a":1,}`) and a leading BOM, keeps the **first** duplicate key, and rejects out-of-range numbers and lone surrogates. | `U/secure-json-parse.ts` (built on `JSON.parse`); `U/parse-json.ts` | `Sources/SwiftAIProvider/SecureJSONParsing.swift` now has a strict ECMA-404 / `JSON.parse` parser: last duplicate key wins, `1e400` gives infinity, lone surrogates become U+FFFD, and the 512-level depth limit is unchanged. Prototype filtering is unchanged. Speed on a 20 MB string matches Foundation. | `parseJSON`, `safeParseJSON`, `isParsableJSON`, `decodeJSONBody` and the speech envelope now reject model or tool-argument JSON with trailing commas, as upstream does (upstream reports this as invalid tool input or a parse error). They also resolve duplicate keys the same way upstream does. **Fixed.** |
| 3 | `withoutTrailingSlash` removed every trailing slash. | `U/without-trailing-slash.ts:2` (`replace(/\/$/, '')`) | `Sources/SwiftAITransport/HTTP.swift:1425-1429` | `https://x/v1//` now becomes `https://x/v1/`, as upstream. **Fixed.** |
| 4 | `validateBaseURL` was missing. Upstream OpenAI, Anthropic and Replicate use it to reject `baseURL: ""` or whitespace. | `U/validate-base-url.ts`; `openai-provider.ts:229-230`, `anthropic-provider.ts:37-38`, `replicate-provider.ts:80` | Added `validateBaseURL(_:)` at `Sources/SwiftAITransport/HTTP.swift:1431-1442` (additive). It throws `AIError.invalidArgument(argument: "baseURL", message: "baseURL must be a non-empty string.")`. | Core helper only. Providers still need to call it (see the reported items). **Fixed in core.** |
| 5 | `AIProviderHTTPClient.rawRequest` added `content-type` and `user-agent` defaults with case-sensitive checks. A caller header `Content-Type` or `User-Agent` therefore produced two spellings, and which one `URLRequest` sent depended on dictionary order. | `U/post-to-api.ts:31-34, 100-104` (`{'Content-Type': ..., ...headers}` then case-insensitive `Headers`) | `Sources/SwiftAITransport/ProviderHTTPClient.swift:58-66` | A caller-supplied content type (for example a multipart boundary) or user agent now always wins, and only one header is sent. **Fixed.** |
| 6 | `AIStreamingToolCallTracker` defaulted to `UUID().uuidString` IDs. Its argument scanner iterated grapheme clusters, so a combining mark after `"`, `{` or `[` hid the structural character, and whitespace checks used Foundation sets rather than JS `\s`. | `U/streaming-tool-call-tracker.ts` (`generateId` default, `createToolCallId`); `U/streaming-tool-call-argument-state.ts` (`for…of` iterates code points; `/\s/`, `trimStart`) | `Sources/SwiftAIProviderUtilities/StreamingToolCallTracker.swift:50, 60-61, 255-306` | Tool-call IDs synthesized for providers without wire IDs are now 16-character alphanumeric IDs, as upstream. Call correlation no longer merges two calls, or splits one, when arguments contain combining marks. **Fixed.** |
| 7 | `mediaTypeToExtension` treated everything after the first `/` as the subtype. | `U/media-type-to-extension.ts:11` (`split('/')`) | `Sources/SwiftAIProviderUtilities/MediaType.swift:88-91` | `audio/mpeg/x` now maps to `mp3`. **Fixed** (edge case). |
| 8 | `SpeechStreamEnvelope.parseClientFrame` returned different `invalid` messages. It merged "malformed JSON" with "frame must be a JSON object", dropped the "when present" and "({ type, rate? })" wording, omitted the `text-delta` prefix on `providerOptions`, and validated `voice` before `speed`. | `U/speech-stream-envelope.ts:121-226`; `U/speech-stream-envelope.test.ts:66-187` | `Sources/SwiftAIProviderUtilities/SpeechStreamEnvelope.swift:21-45` | Servers built on the envelope now report the same rejection messages and the same first error as upstream. **Fixed.** |

### Reported but not fixed

These are cross-package, risky, or platform-adjacent.

- **R1. Providers do not call `validateBaseURL`.** OpenAI, Anthropic and Replicate upstream throw `InvalidArgumentError` for `baseURL: ""` or whitespace. The Swift providers do not; they fail later with an invalid URL or call the wrong host. Providers should call the new `validateBaseURL`. Cross-package.
- **R2. `AIHTTPResponse.jsonValue()` (`HTTP.swift:99`) still uses the lenient `JSONDecoder`.** About 173 provider call sites use it. Upstream `createJsonResponseHandler` parses with `secureJsonParse`. Response bodies therefore still accept trailing commas, keep the first duplicate key, and skip prototype-key filtering. Switching it would change error types (`DecodingError` to `AIJSONParseError`) for every provider while other agents are running provider suites, so it is not done.
- **R3. `getFromAPI` and `deleteFromAPI` (`HTTP.swift:245-275`) set `followRedirects: false`.** Upstream `getFromApi` without `validateUrl` uses plain `fetch`, which follows redirects. A 3xx from a configured endpoint (OpenAI and Anthropic file APIs) surfaces as an API error in Swift. This looks like a deliberate credential-safety choice, but I found it documented nowhere (`Docs/DownloadSecurity.md` covers only untrusted downloads). Not required by the platform.
- **R4. User-Agent differs.** Upstream always appends `ai-sdk-provider-utils/<v> <runtime UA>` after the provider suffix and any caller UA. Swift sends `SwiftAISDK/<providerID>` only when no UA is set, and a configured `userAgentSuffix` replaces that default rather than appending to it. The runtime part is platform-only; the missing package token and the replace-vs-append behavior are a policy choice.
- **R5. `createIdGenerator` calls `preconditionFailure`** (a crash) where upstream throws `InvalidArgumentError` ("The separator … must not be part of the alphabet …"). Fixing it needs a throwing signature, which is a public API change.
- **R6. Error model is Swift-native** (documented in `Docs/CoreV6Parity.md` "AI SDK Errors Reference"). `AIAPICallError.description`, `AIJSONParseError`, `resolveFullMediaType` (`AIError.invalidArgument` instead of `UnsupportedFunctionalityError`, and no URL "not passed as inline bytes" branch because Swift takes `Data`), and `getErrorMessage` (Swift `description` instead of `Error: msg`) all differ in type and text from upstream.
- **R7. `SpeechStreamEnvelope.audioFormat` requires an integer `rate`.** This follows from `AIStreamingAudioFormat.sampleRate: Int`; upstream accepts any finite positive number. `response-metadata.timestamp` accepts ISO 8601 only, where upstream accepts anything `new Date()` parses. Both are type-driven.
- **R8. `convertToMultipartFormData` (internal, unused) iterates a Swift dictionary,** so field order is not insertion order. Platform-only; no caller.
- **R9. `combineHeaders` cannot express `undefined` overrides.** In upstream, `{authorization: undefined}` removes an earlier header; `[String: String]` cannot express that. Platform/API shape.

### Upstream test cases

#### `@ai-sdk/provider` (3 test files)

- `errors/get-error-message.test.ts`: 14 cases. 10 were already translated in root `Tests/SwiftAISDKTests/ProviderErrorMessageTests.swift` (nil, strings, JSON objects/numbers/bools/arrays, custom descriptions). 4 are platform-only: `Error:`/`TypeError:`/`RangeError:` prefixes and the JS `toString` override semantics.
- `json-value.test-d.ts` and `realtime-model-v4.test-d.ts`: type-level only, platform-only.
- Totals: 14 runtime cases: 10 translated, 0 new, 4 platform-only.

#### `@ai-sdk/provider-utils` (about 1,081 `it`/`it.each` occurrences across 106 files)

**Verified case by case and newly translated in this pass** (3 new files, registered in `Porting/map.json`):

- `is-url-supported.test.ts`: 37. The 33 non-RegExp-state cases are translated in `Tests/SwiftAIProviderTests/ProviderUtilsParityTests.swift`; 3 of them are new parameterized cases that fail without fix 1. The 6 "stateful regular expressions" cases are platform-only, because `AISupportedURLPattern` is a closure with no `lastIndex`.
- `secure-json-parse.test.ts`: 12, all translated, plus 30 `JSON.parse` grammar cases (`secureJSONParseUsesJSONParseGrammar`).
- `parse-json.test.ts` (`isParsableJson`): 2 translated. The other 13 are schema/Standard-Schema transforms; partly covered by `JSONParsingTests.swift`, with zod-specific transforms platform-only.
- `without-trailing-slash.test.ts`: 2 of 3 translated, plus a single-slash regression. The `undefined` case is not applicable to a non-optional API.
- `validate-base-url.test.ts`: 3 of 3 (4 inputs).
- `validate-download-url.test.ts`: all 78 URL assertions (21 allowed, 57 blocked) as parameterized tests. All passed without changes, so no divergence.
- `encode-path-segment.test.ts`: 3 of 3 (12 rows plus the per-segment path case).
- `is-valid-hostname-part.test.ts`: 2 of 2 (23 rows).
- `is-same-origin.test.ts`: 4 of 4.
- `normalize-headers.test.ts`: 6 of 6. `Headers` instances map to dictionaries.
- `with-user-agent-suffix.test.ts`: 5 of 5. `Headers` and tuple inputs map to dictionaries.
- `media-type-to-extension.test.ts`: 14 rows, plus a split regression.
- `strip-file-extension.test.ts`: 4 of 4.
- `extract-lines.test.ts`: 8 of 8.
- `speech-stream-envelope.test.ts`: the client-frame invalid cases are translated here (13 rows plus the classify and prototype cases), and they fail without fix 8. Round-trip cases were already in root `WeeklySpeech20261025Tests.swift`.
- `streaming-tool-call-tracker.test.ts` / `streaming-tool-call-argument-state.test.ts`: 2 new regression tests (default ID shape, code-point scanning). The 48+9 behavioral cases are covered by root `StreamingToolCallTrackerTests.swift` (15 tests) plus `WeeklyCore20261011Tests` / `WeeklyImageAndCore20261004Tests`. I compared the implementation line by line with upstream; no further divergence beyond fix 6.
- `ProviderHTTPClient` header-case regression (fix 5): no direct upstream test; it covers `post-to-api.ts` header-merge semantics.

**Already translated (existing Swift tests; checked against source, not re-audited case by case):**

- In root `Tests/SwiftAISDKTests/ProviderUtilsUpstreamParityTests.swift`: as-array, filter-nullable, remove-undefined-entries, generate-id (3 of 4), create-tool-name-mapping, map-reasoning-to-provider, inject-json-instruction, delay, delayed-promise.
- In `MediaTypeTests.swift`: detect-media-type (73, signatures/ID3/AAC/AVIF/HEIC/top-level), resolve-full-media-type (inline-bytes cases).
- In `ProviderReferenceTests.swift`: is-provider-reference / resolve-provider-reference.
- In package tests: add-additional-properties-to-json-schema (`JSONSchemaTransformationTests`), resolve-provider-options (`Weekly20261108UtilitiesTests`), read-response-with-size-limit (`HTTPResponseSizeLimitTests`), fetch-with-validated-redirects and fetch-untrusted-url (`HTTPRedirectSecurityTests`, `HTTPDNSPinningTests`), convert-to-form-data (`MultipartFormDataTests`), is-json-serializable (`JSONParsingTests`).
- In other weekly tests: map-reasoning-to-provider.

**Still missing, with reasons:**

- `generate-id.test.ts` separator-in-alphabet throw: 1 case, cannot be translated because it would crash (R5).
- `response-handler*.test.ts` (44), `post-to-api` (1), `get-from-api` (18), `delete-from-api` (2), `post-multipart-stream-to-api` (7), `handle-fetch-error` (10), `download-blob` (22), `cancel-response-body` (3): Swift core has no response-handler or `fetch` abstraction. Providers own their parsing, and `getFromAPI` is a thin transport call (R3). Not translatable without new API.
- `json-binary-field-scanner` (51): no Swift surface. It is a JS performance optimization for `experimental_binaryFields`, not applicable.
- `transcription-stream-envelope` (30): implemented in `swift-ai-gateway`, not core (out of scope).
- `serialize-model-options` (8), `resolve.test` (18), `is-abort-error` (4), `is-browser-runtime` (2), `cross-realm-file-data` (2), `uint8-utils*` (27), `convert-async-iterator-to-readable-stream` (4), `stringify-with-bigint-and-cycles` (5), `is-record` (2), `get-runtime-environment-user-agent` (4), `websocket` / `connect-to-websocket` (17), `has-required-key`, `schema.test-d`, `types/*.test-d`: JS runtime, realm or type-level behavior. Platform-only.
- `to-json-schema/zod3-to-json-schema/**` (about 190): zod-specific, platform-only.
- `schema.test.ts` (31), `validate-types` (4), `types/executable-tool` and `types/execute-tool` (7): Standard Schema and tool-execution helpers live in `SwiftAI` (other agent).
- `decision-language-model` / `extraction-language-model` (48), `convert-json-response-tool-stream` (5), `create-null-language-model-usage` (2), `create-provider-stream-error` (2), `normalize-batch-request-counts` (2), `convert-image-model-file-to-data-uri` (7), `convert-inline-file-data-to-uint8-array` (7): not re-audited in this pass for lack of time. Swift equivalents exist in `DecisionLanguageModel.swift`, `ExtractionLanguageModel.swift`, `StreamProviderError.swift`, `CoreBatch.swift` and provider packages.

### Platform-driven differences relied on

- Swift error enums and structs instead of `AI_*` classes.
- Closures instead of `RegExp` for supported-URL patterns.
- `[String: String]` headers.
- `URLSession` transport.
- Lone surrogates decode to U+FFFD.
- A depth limit of 512 for JSON nesting.

### Files changed

- `Packages/swift-ai-core/Sources/SwiftAIProvider/CoreProtocols.swift`
- `Packages/swift-ai-core/Sources/SwiftAIProvider/SecureJSONParsing.swift`
- `Packages/swift-ai-core/Sources/SwiftAITransport/HTTP.swift`
- `Packages/swift-ai-core/Sources/SwiftAITransport/ProviderHTTPClient.swift`
- `Packages/swift-ai-core/Sources/SwiftAIProviderUtilities/StreamingToolCallTracker.swift`
- `Packages/swift-ai-core/Sources/SwiftAIProviderUtilities/MediaType.swift`
- `Packages/swift-ai-core/Sources/SwiftAIProviderUtilities/SpeechStreamEnvelope.swift`
- `Packages/swift-ai-core/Tests/SwiftAIProviderTests/ProviderUtilsParityTests.swift` (new)
- `Packages/swift-ai-core/Tests/SwiftAIProviderUtilitiesTests/ProviderUtilsHelperParityTests.swift` (new)
- `Packages/swift-ai-core/Tests/SwiftAITransportTests/ProviderUtilsTransportParityTests.swift` (new)
- `Packages/swift-ai-core/Porting/map.json`: registered the 3 new test files. Another agent's `AiCoreParity20261116Tests.swift` entry was preserved.

### Test results

`swift test --package-path Packages/swift-ai-core --scratch-path .build/agent-core-provider --no-parallel` passed:

| Suite | Tests | Suites |
|---|---|---|
| SwiftAITransportTests | 94 | 4 |
| SwiftAITests | 107 | 11 |
| SwiftAIProviderUtilitiesTests | 56 | 2 |
| SwiftAIProviderTests | 15 | 2 |

The parameterized cases expand further: 21 + 57 download URLs and 3 media types.

The root compatibility suite did not run. `node Scripts/sdk.mjs dev test --filter …` aborted in workspace preparation with "Unowned workspace input Packages/swift-ai-baseten/Tests/SwiftAIBasetenTests/BasetenUpstreamParityTests.swift", a file another agent is adding. As a result, root tests such as `ProviderUtilsUpstreamParityTests`, `MediaTypeTests` and `StreamingToolCallTrackerTests` were not re-run against the new sources. By inspection none of them asserts the old behavior: no `image/png` prefix cases, no multiple-trailing-slash cases, and no UUID-shaped tracker IDs. `node Scripts/test-packages.mjs` was not run either.

## OpenAI and Azure

## Parity audit: openai-azure

Packages: `@ai-sdk/openai` 4.0.118 → `Packages/swift-ai-openai`; `@ai-sdk/azure` 4.0.126 → `Packages/swift-ai-azure`.
Upstream: `scratchpad/upstream-all/pkg/{openai,azure}` (npm `src` is byte-identical to `repo-src` non-test files).

### Method and coverage limits

The fan-out plan (one sub-agent per upstream test area) could not run: the session-wide sub-agent concurrency
limit was already reached. The audit was therefore done by one agent, probe-first: I read the upstream
request-preparation code (`chat/openai-chat-language-model.ts#getArgs`,
`responses/openai-responses-language-model.ts#prepareRequest`, `convert-to-openai-responses-input.ts`,
`openai-model-catalog.ts`, `transcription/*`, `embedding/*`, `image/*`, `azure-openai-provider.ts`), wrote throw-away
Swift probe tests that ran the same inputs through the Swift providers, and diffed the request bodies and warnings.
Every confirmed divergence was then fixed (when it lives in my packages) and covered by translated upstream tests.

I did **not** finish a per-`it()` mapping of all ~1,225 upstream cases. The per-file "already translated" column below
is therefore not given as a number. Areas I checked by probe or code reading and found matching: embeddings request
body (`dimensions` precedence, `encoding_format`, `user`), Responses no-output error text, batch no-output text,
transcription defaults (`verbose_json`/`diarized_json`, `chunking_strategy: auto`, timestamp-granularity warnings),
Azure URL building (all 7 base-URL forms, gateway, deployment URLs, `api-version`), Azure option-namespace
precedence (chat merge with `azure` winning; Responses first-namespace-wins), Azure DeepSeek routing and options.

### Upstream test inventory (cases = `it`/`test`, an `it.each` counts as one)

| Upstream file | Cases | Newly translated here | Notes |
|---|---:|---:|---|
| chat/openai-chat-language-model.test.ts | 128 | 16 (+3 supplemental) | settings, response format (json_object / json_schema / propertyNames / name+description), reasoning models, GPT-6 strip, search preview ×3, service tier flex/priority/fast/ultrafast, reasoningSummary |
| chat/convert-to-openai-chat-messages.test.ts | 45 | 0 | implementation in openai-compatible (not audited case-by-case) |
| chat/openai-chat-prepare-tools.test.ts | 14 | 1 | tool schema sent unchanged |
| chat/convert-openai-chat-usage.test.ts | 1 | 0 | |
| completion/openai-completion-language-model.test.ts | 19 | 0 | openai-compatible |
| embedding/openai-embedding-model.test.ts | 8 | 0 | probe matched |
| image/openai-image-model.test.ts | 37 | 0 | warning divergence reported (D-R1) |
| responses/openai-responses-language-model.test.ts | 243 | 4 (+1 supplemental) | service tier, GPT-6 warning order, includeWebSearchSources |
| responses/convert-to-openai-responses-input.test.ts | 158 | 10 | system modes, breakpoints, imageDetail (openai/azure), filenames, unsupported files, pass-through |
| responses/openai-responses-reasoning-effort-update.test.ts | 22 | 1 | historical `none` update message |
| other responses tests (api 18, prepare-tools 84, text-format-update 12, computer 3, tool-search 1, expand-parallel 2, prompt-cache-diagnostics 0) | 120 | 0 | not mapped |
| transcription 51, speech 10, speech-translation 17, files 21, skills 6, batch 26, decision 21, extraction 1, provider 7, error 1, stream-error 11, normalize-schema 7, capabilities 2, forward-compatible 3, lazy-schemas 3, live 26, realtime 27 | 241 | 0 | spot-checked only |
| **openai total** | **1038** | **31 (+4)** | |
| azure-openai-provider.test.ts | 87 | 6 | azure-key options, merge precedence, DeepSeek json_schema and azure namespace, Azure chat json_schema/service-tier/reasoningSummary |
| azure-transcription 35, azure-speech 22, azure-mai-transcription 18, azure-mai-image 20, mai-generate-image 2, image-download-auth 1, model-id 1, lazy-schemas 1 | 100 | 1 (lazy resource, supplemental) | not mapped |
| **azure total** | **187** | **6 (+1)** | |

Still missing, with reasons: the unmapped files above were not compared case-by-case because of the single-agent time
budget, not because they are untranslatable. Cases that cannot be translated as written: `fileIdPrefixes` /
string-data file IDs (Swift file parts carry `Data`, so provider references are the only file-ID path); PDF/file URL
parts (core `AIContentPart` only has `imageURL`; reported as C-1); `*.test-d.ts` type tests; zod lazy-schema tests.

### Fixed divergences

| # | Upstream evidence | Swift evidence (before) | User-visible effect | Verdict |
|---|---|---|---|---|
| F1 | `chat/openai-chat-language-model.ts:244-262` always emits `json_schema` when a schema is present | `OpenAIConfiguration.swift` `compatibleConfiguration()` forwarded `supportsStructuredOutputs` (default `false`), so the shared adapter sent `{"type":"json_object"}` | OpenAI and Azure chat with a JSON schema got no schema enforcement unless the caller set an undocumented flag | fixed (`OpenAIConfiguration.swift:104`) |
| F2 | same block sends the normalized schema unchanged | shared strict path (`OpenAICompatibleChatCommon.swift` `openAICompatibleResponseFormat`) added `additionalProperties: false` to every object schema | request schema differed from the caller's schema | fixed via `prepareBody` (`OpenAIConfiguration.swift:151`) |
| F3 | `openai-chat-language-model.ts:384-410`, `openai-responses-language-model.ts:791-820` drop unsupported `flex` / `priority`/`fast` tiers with warnings | no service-tier validation anywhere | unsupported tiers were sent to the API (likely a 400) and no warning was returned | fixed for Chat (`prepareBody`) and Responses (`OpenAIResponsesModel.swift:966`); capability flags added to `OpenAILanguageModelCapabilities` (additive) |
| F4 | `openai-chat-language-model.ts:372-381` removes `temperature` for `gpt-4o(-mini)-search-preview*` | not implemented | search-preview requests sent `temperature` | fixed (`prepareBody`) |
| F5 | `openai-chat-language-model.ts:128,190-199` warns for `reasoningSummary` under `openai` **or** `azure`; the chat schema strips the key | warned for `openai` only and leaked `reasoningSummary` into the chat body for both namespaces | invalid body field; Azure got no warning | fixed (`prepareBody`) |
| F6 | `openai-responses-language-model.ts:415-430`, `convert-to-openai-responses-input.ts:587-640` honour `systemMessageMode` (`system`/`developer`/`remove` + warning) | option ignored and sent to the API as `systemMessageMode` | `remove`/`system` overrides had no effect; unknown body field | fixed (`OpenAIResponsesModel.swift:752,891`; `OpenAIResponsesOptions.swift:523`) |
| F7 | `convert-to-openai-responses-input.ts:589-622` emits `prompt_cache_breakpoint` on system messages | system content always a plain string | system-message cache breakpoints were dropped | fixed |
| F8 | `convert-to-openai-responses-input.ts:650-760`: `imageDetail` → `detail`; breakpoints on image/file/reference parts; `filename: part.filename ?? part-N[.pdf]`; non-PDF files throw `file part media type …` unless `passThroughUnsupportedFiles` | `detail` and image/file breakpoints dropped; filename ignored; any media type sent; `passThroughUnsupportedFiles` leaked into the body | lost image detail and cache control; wrong filenames; unsupported files reached the API | fixed (`OpenAIResponsesOptions.swift:1175-1240`), only for OpenAI-backed providers |
| F9 | `openai-responses-language-model.ts:579-585` skips `web_search_call.action.sources` when `includeWebSearchSources: false` | option ignored and sent to the API | could not opt out of the sources include; unknown body field | fixed (`OpenAIResponsesModel.swift:755,789`) |
| F10 | `openai-responses-language-model.ts:700-760` warning order: `promptCacheRetention`, `temperature`, `topP`, `logprobs` | `logprobs` came before `temperature`/`topP` | warning order differed (upstream test asserts it) | fixed (`OpenAIResponsesModel.swift:948-964`) |
| F11 | `openai-responses-language-model.ts:454` message `"<modelId> only supports the following reasoning efforts: …"` | `"The selected model only supports these reasoning efforts: ….`" | different error text | fixed; `Weekly20261114ResponsesTests.swift` expectation updated |
| F12 | `azure-openai-provider.ts` resolves the resource name lazily, per request | `AzureOpenAIProvider.init` threw when neither `baseURL` nor a resource name existed, even with `speechBaseURL`/`maiBaseURL` | Speech/MAI-only configurations could not be created | fixed (`AzureOpenAIProvider.swift:45-52`); Azure OpenAI requests now fail lazily with the same `invalidURL` error and send nothing |

### Reported, not fixed

| # | Upstream evidence | Swift evidence | Effect | Why not fixed |
|---|---|---|---|---|
| R1 | `image/openai-image-model.ts:110-123` warns `aspectRatio` and `seed` (test "should return warnings for unsupported settings") | `swift-ai-openai-compatible/.../OpenAICompatibleMediaModels.swift:295` returns `[]` for OpenAI-backed providers | OpenAI/Azure image calls silently ignore `aspectRatio`/`seed` | code lives in openai-compatible; fix: drop the OpenAI-backed early return |
| R2 | umbrella should mirror the package chat policy | `Sources/SwiftAISDK/Providers/OpenAICompatibleCompatibility.swift:22,41` sets `supportsStructuredOutputs` from settings and overwrites `prepareBody` | `AIProviders.openAI(settings:)`/umbrella chat still has F1–F5 | umbrella is read-only; fix: for `openai`/`azure` roots use `openAIWire.supportsStructuredOutputs` and call `openAIWire.prepareBody` inside the umbrella closure |
| R3 | provider options are zod-parsed; unknown keys are stripped (`resolveProviderOptions`) | `swift-ai-openai-compatible/.../OpenAICompatibleProviderOptions.swift:26-36,253-260` merges every key; Responses/Chat `body.merge(options)` | unknown provider options (e.g. typos, `include` on chat) are sent to OpenAI | behaviour change for existing callers and shared helper; needs a design decision (Swift `extraBody` is the escape hatch) |
| R4 | Responses schema has no `maxCompletionTokens` | `OpenAIResponsesOptions.swift` `openAIResponsesOptions` maps `maxCompletionTokens` → `max_output_tokens`, overriding `maxOutputTokens` | Swift-only extension, undocumented | not upstream behaviour, but removing it could break callers; decide and document |
| R5 | Chat warning order: reasoning compat, mapping, `topK`, `reasoningSummary`, message/schema, sampling, service tier, **tool warnings last** | `OpenAICompatibleChatCommon.swift:140-160` emits tool warnings first; F3–F5 warnings are appended after tool warnings | order differs only when tool warnings coexist | openai-compatible |
| R6 | Responses order: input-conversion warnings before non-reasoning warnings; tool warnings last | `OpenAIResponsesModel.swift` adds tool warnings before input warnings and non-reasoning warnings before input warnings | order differs only with mixed warnings | larger restructuring; low impact |
| R7 | Azure `OpenAIEmbeddingModel` reads only `providerOptions.openai` | Swift merges `azure` too | `azure.dimensions/user` honoured in Swift only | lenient superset; low impact |
| C-1 | `convert-to-openai-responses-input.ts:700-735` sends PDF URLs as `input_file.file_url` | core `AIContentPart` has only `imageURL` | a PDF URL cannot be expressed | core API |
| C-2 | tool arrays keep declaration order | `LanguageModelRequest.tools` is a dictionary | `tools` order in request bodies is not the caller's order | core API |
| C-3 | message-level errors are `UnsupportedFunctionalityError` | Swift uses `AIError.invalidArgument` (no unsupported-functionality case) | error type differs, message matches | core API (platform) |

Platform-only differences relied on: eager `missingAPIKey` / invalid-resource errors at provider construction
(project-wide Swift convention; F12 only relaxes the audio-only case), `AudioTranscriptionRequest.fileName`
instead of `audio.<ext>`, `Data` file payloads instead of base64/file-ID strings.

### Files changed

- `Packages/swift-ai-openai/Sources/SwiftAIOpenAI/OpenAIConfiguration.swift` — F1–F5 (`openAIChatApplyModelRestrictions`, structured outputs)
- `Packages/swift-ai-openai/Sources/SwiftAIOpenAI/OpenAIResponsesOptions.swift` — capability flags, `openAIServiceTierUnsupportedWarning`, system modes, part options, file rules, error text
- `Packages/swift-ai-openai/Sources/SwiftAIOpenAI/OpenAIResponsesModel.swift` — option extraction, service tier, warning order
- `Packages/swift-ai-openai/Tests/SwiftAIOpenAITests/ParityOpenAIChatTests.swift` (new, 18 tests)
- `Packages/swift-ai-openai/Tests/SwiftAIOpenAITests/ParityOpenAIResponsesTests.swift` (new, 14 tests)
- `Packages/swift-ai-openai/Tests/SwiftAIOpenAITests/Weekly20261114ResponsesTests.swift` — upstream error text
- `Packages/swift-ai-openai/Porting/map.json`, `Packages/swift-ai-azure/Porting/map.json` — register new tests
- `Packages/swift-ai-azure/Sources/SwiftAIAzure/AzureOpenAIProvider.swift` — F12
- `Packages/swift-ai-azure/Tests/SwiftAIAzureTests/ParityAzureTests.swift` (new, 7 tests)
- `docs-site/scripts/provider-guides/openai.md`, `azure.md` — documented new options, file rules, service-tier and json_schema behaviour, audio-only Azure setup

### Test results

- `swift test --package-path Packages/swift-ai-openai --no-parallel`: 340 Swift Testing tests passed.
  `openAILiveSessionStartsCorrelatesContextAndConfirmsClose` failed once in an earlier full run (WebSocket close-code
  timing) and passed 3/3 in isolation and in the final full run; it is unrelated to these changes.
- `swift test --package-path Packages/swift-ai-azure --no-parallel`: 44 tests passed.
- Root compatibility tests (`node Scripts/sdk.mjs dev test --filter "OpenAI|Responses|Azure"`) could not run: the
  dev workspace refuses to build because another agent's file
  `Packages/swift-ai-amazon-bedrock/Tests/SwiftAIAmazonBedrockTests/AmazonBedrockParityAuditTests.swift` is not yet
  registered in its `map.json`. Re-run once that lands; the Responses changes (F6–F11) reach the umbrella.

## Anthropic, Anthropic AWS and Amazon Bedrock

## Parity audit: anthropic-bedrock group

Packages: `@ai-sdk/anthropic` 4.0.105 → `Packages/swift-ai-anthropic`, `@ai-sdk/anthropic-aws` 2.0.98 → `Packages/swift-ai-anthropic-aws`, `@ai-sdk/amazon-bedrock` 5.0.142 → `Packages/swift-ai-amazon-bedrock`.
Upstream paths below are relative to `scratchpad/upstream-all/pkg/<slug>/npm/src` (source) or `.../repo-src` (tests).

---

### @ai-sdk/anthropic → swift-ai-anthropic

#### Upstream test cases

`it`/`it.each` declarations (before `.each` expansion): 759.
- `anthropic-language-model.test.ts`: 370
- `convert-to-anthropic-prompt.test.ts`: 108
- `anthropic-prepare-tools.test.ts`: 67
- `files/anthropic-files.test.ts`: 40
- `anthropic-batch.test.ts`: 40
- `anthropic-provider.test.ts`: 20
- `convert-anthropic-usage.test.ts`: 15
- `anthropic-message-threads.test.ts`: 15
- `anthropic-json-response-tool-fallback.test.ts`: 14
- `supports-native-structured-output-schema.test.ts`: 12
- `has-circular-schema-reference.test.ts`: 10
- `anthropic-decision.test.ts`: 8
- `skills/anthropic-skills.test.ts`: 7
- `sanitize-json-schema`, `anthropic-service-tier`, `anthropic-forced-tool-structured-output`: 6 each
- the remaining nine small files: 1–4 each

**Already translated (before this pass):** about 170 Swift tests exist, in the package's 27 test files plus the root `Tests/SwiftAISDKTests/Anthropic*.swift`. Many assert with `.contains` or only some of the fields, so they did not catch warning-order, `max_tokens` or extra-field differences. I counted roughly 150 upstream cases as genuinely covered.

**Newly translated (26)**, all in `Tests/SwiftAIAnthropicTests/AnthropicParityAuditTests.swift`, which is registered in `Porting/map.json`. They assert exact bodies and complete, ordered warning arrays.
- **Thinking and token limits.**
  - Thinking enabled with sampling parameters: exact body and the upstream warning order.
  - Default thinking budget: `max_tokens` 64000.
  - Top-level reasoning budget with no `maxOutputTokens`.
  - `maxOutputTokens` limited to the model maximum, plus the unknown-model case.
- **Sampling and warnings.**
  - Temperature clamping (3 cases).
  - Clamp, then reject, in upstream order with JavaScript number formatting.
  - Unknown Claude model strips sampling parameters.
- **Options mapping.**
  - Thinking-variant field stripping.
  - Agent skills: 4 cases (request body, missing-code-execution warning, beta headers with no container ID, `NoSuchProviderReferenceError`).
  - Tools with a named tool choice: exact body.
- **Prompt conversion.**
  - Signed, unsigned, redacted and `sendReasoning: false` reasoning (4 cases).
  - Assistant text citations.
  - Empty compaction-only assistant message.
  - Signed versus unsigned compaction beta.
  - Prefill trim.
  - PDF filename title.
  - Approval parts skipped.
- **Streaming.**
  - `response-metadata` carries the message ID and model.
  - An unknown first-chunk stream error is not retryable.

**Still missing:** roughly 590 cases.
- `anthropic-language-model.test.ts` snapshot-heavy stream/generate fixture cases: about 250. Not translated for time; the biggest gap is the full stream part sequences for provider tools such as web fetch/search, tool search, code execution and advisor.
- Prompt conversion: about 70. Provider-executed tool round trips and cache-control variants were left for time.
- prepare-tools: about 50.
- batch: about 26.
- files: about 30.
- Platform-only, not translatable:
  - `*.test-d.ts` type tests
  - `lazy-schemas`
  - `new`-keyword checks
  - BigInt/circular serialization
  - `topK: 0.1` (Swift `topK` is `Int`)
  - zod validation-error shapes
  - workflow serialization
  - `fetch`/`ReadableStream` tee mechanics

#### Divergences

| # | Upstream evidence | Swift evidence (before fix) | Verdict | User-visible effect |
|---|---|---|---|---|
| 1 | `anthropic-language-model.ts:956` (`maxTokens = maxOutputTokens ?? maxOutputTokensForModel`) and `:1173` (`max_tokens = maxTokens + thinkingBudget`) | `AnthropicOptions.swift` `applyAnthropicThinkingRules`: `(requestedMaxTokens ?? 1024) + budget` | **fixed** | With enabled/budget thinking and no `maxOutputTokens`, Swift sent `1024 + budget` (for example 2048, or 7424 for `reasoning: "low"`). Upstream sends `modelMax + budget`, limited to the model maximum (for example 64000). Responses were truncated. |
| 2 | `:1050-1083` builds `container.skills[].skill_id` via `resolveProviderReference({provider:'anthropic'})`; the container is omitted when there is no `id` and no skills | `anthropicContainer` only renamed `skillId`. Custom `providerReference` was sent raw, with no `skill_id` and no error. | **fixed** (`anthropicTypedContainer`) | Custom skills now get a resolved `skill_id`. A missing `anthropic` reference throws `AINoSuchProviderReferenceError`. |
| 3 | Option schema (`anthropic-language-model-options.ts`, `thinking` discriminated union, `metadata.userId`); body construction at `:961-974` and `:1032-1034` | Thinking and metadata objects were forwarded with every key | **fixed** (`anthropicTypedThinking`, metadata mapping) | `budget_tokens` on adaptive thinking, or `display` on enabled thinking, is no longer sent. Metadata sends only `user_id`. |
| 4 | `:441-930` and `:1438` (`warnings: [...warnings, ...toolWarnings, ...cacheWarnings]`) | `AnthropicModels.swift` `body(for:)`: prompt warnings came before the unknown-model and sampling warnings. Tool warnings came before the thinking, max-token and skills warnings. Thread warnings came after tools. Cache warnings were interleaved. | **fixed** (request builder reordered) | The `warnings` array now has the upstream order. |
| 5 | `:441-475` clamps the temperature before `rejectsSamplingParameters` (`:567-591`), and both warnings are emitted. The message uses JavaScript `${temperature}` and `toFixed(1)`. | `anthropicSamplingParameters` skipped the clamp warning for models that reject sampling and printed `2.0` | **fixed** | Missing clamp warning on Opus 4.7+, and wrong number text (`"2.0 exceeds…"` instead of `"2 exceeds…"`). |
| 6 | `:518-521` serviceTier details `Use "auto" or "standard_only".` | The tiers were not quoted | **fixed** | Warning text. |
| 7 | `:687-697`: the JSON tool path warns `toolChoice 'required'…` when `rejectsForcedToolUse` | Swift warned only when thinking was enabled | **fixed** | Missing warning for forced-tool-rejecting models whose schema falls back to the JSON tool. |
| 8 | `:1108-1114` skills warning only for `code_execution_20250825`/`20260120` | Any code-execution tool, including `20250522`, suppressed the warning | **fixed** | Warning parity. |
| 9 | `:500-511` `Object.assign(canonical, custom)` at the option level | A custom-namespace `output_config` replaced the canonical one | **fixed** | `effort` from `anthropic` plus `taskBudget` from a custom namespace (or the reverse) no longer drops one of them. |
| 10 | `convert-to-anthropic-prompt.ts:959-1004`: signed reasoning becomes `thinking`; `redactedData` becomes `redacted_thinking`; anything else is dropped with `unsupported reasoning metadata` | `.reasoning` parts were always sent as `thinking`, with no signature when absent | **fixed** | Round-tripped redacted reasoning was sent as an empty unsigned `thinking` block, which the API rejects. Unsigned reasoning was sent instead of being dropped. |
| 11 | `:942-948` replays `textMetadata.citations` on assistant text | Citations were applied only to document blocks | **fixed** | Web-search citations (`encrypted_index`) were lost on follow-up turns. |
| 12 | `:922-937`: compaction beta only when `signature` is a string; `cache_control` honoured | The beta was always added and `cache_control` was ignored | **fixed** | Unneeded beta header; missing cache breakpoint. |
| 13 | `:951-954` uses `trim()` on the final prefill text | Only trailing whitespace was removed | **fixed** | Leading whitespace in the final prefill part. |
| 14 | `:577-582` PDF title is `metadata.title ?? part.filename` | The PDF block had no title from the filename | **fixed** | Missing document title. |
| 15 | User/assistant switch statements and `:659` ignore approval, reasoning-file and assistant file parts | Approval and reasoning-file parts became `{"type":"text","text":""}`; assistant files became image/document blocks | **fixed** | Empty text blocks are rejected by the API (HTTP 400). Assistant media blocks are invalid. |
| 16 | `groupIntoBlocks` (`:1740-1790`): an empty assistant block still separates the user blocks around it (test "should omit an assistant message that only contains an empty compaction block") | The skipped assistant message let the next user message merge into the previous one | **fixed** | Message structure. |
| 17 | `:3365-3370` emits `response-metadata {id, modelId}` at each `message_start` | Only an HTTP-level `responseMetadata` with `id: nil` and the request model ID | **fixed** | `streamText` response `id` was nil, and `modelID` was the requested ID instead of the served model. |
| 18 | `:3655-3672` startup stream error uses `isRetryable: error.isRetryable ?? false` | The core default made an unknown error type (status 500) retryable | **fixed** | Retry behaviour for unknown stream error types. |
| 19 | `anthropic-provider.ts:159` and `:180` use truthiness for `apiKey`/`authToken` | `apiKey: ""` together with an authToken threw, and `authToken: ""` sent `Bearer ` | **fixed** | Edge-case credentials. |
| 20 | `anthropic-model-catalog.ts`: `includes('claude-fable-5-2') \|\| includes('claude-fable-5-1')` | `AnthropicOptions.swift` uses the regex `claude-fable-5-(?:1\|2)(?=$\|[-@:.])` | **documented-intentional, not platform-required: reported, not fixed** | Dated base Fable 5 IDs such as `claude-fable-5-20260101` keep forced tool use in Swift; upstream treats them as Fable 5.2 (rejects forced tool use). Documented only in `Docs/Archive/WeeklyUpstreamAudit20261114.md`. |
| 21 | `anthropic-error.ts` plus `:3655` APICallError: `message` = error message, `responseBody` = wire body / `JSON.stringify(error.data)` | `anthropicHTTPStatusError` and `anthropicStreamError` put the message in `responseBody` (`message` nil) unless `details` is non-null | **reported** (cross-provider convention; Bedrock does the same) | `AIAPICallError.responseBody` holds "Overloaded" instead of the raw JSON. Core documents that `responseBody` retains the wire body. Needs a project-wide decision; existing package tests pin the current shape. |
| 22 | Prepare-tools keeps the caller's tool order | `LanguageModelRequest.tools` is a dictionary (sorted keys) | **platform/core-only** | Tool order differs from the caller's order. |
| 23 | The `anthropic-beta` header lists automatic betas, then user-supplied header betas, then `anthropicBeta` (`:1440-1446`) | `anthropicHeaders` puts config/request header betas first | **reported (minor)** | Header value order only; the betas are semantically equivalent. |
| 24 | Stream `reasoning-end` for `redacted_thinking` has no providerMetadata | Swift repeats `redactedData` on `reasoningEnd`; a root test pins this (`AnthropicStreamingAndClientsTests.swift:702`) | **reported (minor)** | Extra metadata on the end part. |
| 25 | Unsupported user media throws `UnsupportedFunctionalityError("media type: …")` | Swift throws `AIError.invalidArgument` ("Unsupported media type: …") | **platform/core-only** | The core has no general UnsupportedFunctionality error. |

**Umbrella (read-only):** `Sources/SwiftAISDK/Providers/AnthropicProvider.swift`, `AnthropicCompatibility.swift` and `ProviderCapabilityMatrix.swift` delegate to the package. I found no separate re-implemented capability list for Anthropic models.

#### Files changed
- `Packages/swift-ai-anthropic/Sources/SwiftAIAnthropic/AnthropicOptions.swift`
- `Packages/swift-ai-anthropic/Sources/SwiftAIAnthropic/AnthropicModels.swift`
- `Packages/swift-ai-anthropic/Sources/SwiftAIAnthropic/AnthropicParsing.swift`
- `Packages/swift-ai-anthropic/Sources/SwiftAIAnthropic/AnthropicProvider.swift`
- `Packages/swift-ai-anthropic/Tests/SwiftAIAnthropicTests/AnthropicParityAuditTests.swift` (new)
- `Packages/swift-ai-anthropic/Porting/map.json`

#### Tests
- `swift test --package-path Packages/swift-ai-anthropic --no-parallel`: 204 passed (was 178).
- Dependants re-run after the Anthropic changes, all passing:
  - `swift-ai-amazon-bedrock`: 94
  - `swift-ai-anthropic-aws`: 15
  - `swift-ai-minimax`: 70
  - `swift-ai-google-vertex`: 56
- `node Scripts/sdk.mjs catalog validate`: valid.
- Root compatibility suite: not run. Root tests that may be affected and should be re-run: `Tests/SwiftAISDKTests/Anthropic*.swift`, especially the ones asserting `max_tokens` with thinking, warning order, or stream `responseMetadata` counts.

---

### @ai-sdk/amazon-bedrock → swift-ai-amazon-bedrock

#### Upstream test cases

596 `it`/`it.each` declarations across 27 files.
- chat-language-model: 207
- convert-messages: 93
- prepare-tools: 42
- provider: 30
- image: 30
- sigv4-fetch: 28
- Bedrock-Anthropic provider / fetch / structured-output: 31 / 13 / 5

**Before this audit:** about 60 had a Swift equivalent with matching assertions. `amazonBedrockPreservesCompleteRawUsageInProviderMetadata` was mis-translated: upstream checks `usage.raw` and the normalized usage, not provider metadata.

**Newly translated (30):** 28 in the new `AmazonBedrockParityAuditTests.swift` (registered in `Porting/map.json`), plus the event-stream raw-usage test and a corrected raw-usage generate test.

**Still missing:** roughly 500, for time.
- the 207 chat snapshot/fixture cases
- most prepare-tools and conversion cases
- image (30), embedding (16), Bedrock-Anthropic (49), Mantle (16)

**Platform-only, not translatable:**
- sigv4-fetch Request/Headers/ArrayBuffer and lazy-fetch cases
- `lazy-schemas`, `inject-fetch-headers`
- `new`-keyword, BigInt/circular-JSON
- zod-validation cases

#### Divergences fixed
1. **Usage** (`convert-amazon-bedrock-usage.ts:19-43`). Input tokens now include cache read and write, and the cache breakdown and raw usage are filled in. Before, cache tokens were dropped.
2. **Provider metadata** (`chat-language-model.ts:922-964`, `1135-1183`, `1441-1457`).
   - `usage` carries only `cacheWriteInputTokens`/`cacheDetails`.
   - `stopSequence` is always present on generate (null when absent). On stream it is added from `messageStop` only when non-null, together with `isJsonResponseFromTool`.
   - No extra `.metadata` stream parts.
3. **Response metadata** (`:976-984`, `:1050-1058`). The id comes from `x-amzn-requestid`, the timestamp from the `date` header, plus model ID and headers, on both generate and stream. Before, there was none.
4. **`additionalModelResponseFieldPaths: ["/delta/stop_sequence"]`** is now sent for Anthropic models (`:749-760`).
5. **`anthropicBeta` and provider-tool betas** now go into `additionalModelRequestFields.anthropic_beta` (`:488-499`, `prepare-tools.ts:118-133`). Before, they were dropped.
   - The bash tool now sends the upstream input schema.
   - Anthropic tool-choice and warnings were ported.
6. **Provider-option namespaces** (`:165-175`, `:738-745`).
   - `amazonBedrock` wins over `bedrock` instead of merging; the same applies to embedding and image options.
   - Unknown keys pass through into the body, as upstream does (this includes upstream's top-level `anthropicBeta` quirk).
7. **Message conversion** (`convert-to-amazon-bedrock-chat-messages.ts:174-578`).
   - Consecutive user/tool messages and consecutive assistant messages are grouped.
   - A system message after other messages throws.
   - Whitespace-only assistant text is skipped, and the final prefill is trimmed.
   - Ignored parts no longer become blank `{"text":""}` blocks.
   - `providerReference` parts throw.
   - Tool results no longer send `status`.
   - An untyped JSON tool result is sent as text.
   - Cache points are read only from the `amazonBedrock`/`bedrock` namespaces.
8. **Tool content with no active tools** (`:682-720`) is stripped with one warning.
9. **Tool definitions** (`:443-454`).
   - The JSON tool description is "Respond with a JSON object."
   - Schemas no longer leak `description`/`strict`.
   - Strict and filtering logic is aligned.
10. **Warning order** follows upstream, with JavaScript number formatting.
11. **Stream state machine** (`:1061-1440`).
    - A text block start emits text-start.
    - Blocks never stopped are not auto-closed.
    - JSON tool text is emitted at block stop.
    - Empty tool deltas are emitted; deltas for unregistered blocks are ignored.
    - The reasoning-delta branches form an else-if chain.
    - Raw chunks drop the `p` padding field.
    - The old test that asserted progressive JSON tool deltas was rewritten.
12. **Generate parsing.** No `rawInvalidInput` wrapping; null signatures produce no reasoning metadata.
13. **Error messages.** Converse generate and Bedrock-Anthropic report only the provider message (`:816-819`). Bedrock-Anthropic strips `eager_input_streaming` and adds the `fine-grained-tool-streaming-2025-05-14` beta.

#### Reported, not fixed
- **SigV4 path encoding (core, `swift-ai-core/Sources/SwiftAITransport/AWSSigV4.swift:102-105`).** aws4fetch is believed to double-encode the path for non-S3 services, so `%3A` would be signed as `%253A`. If that is right, signatures fail for every model ID containing `:`. This needs a known-answer or live check. Core also adds `x-amz-content-sha256`, which aws4fetch does not.
- **Mantle chat** uses the generic compatible profile rather than the OpenAI chat model (`AmazonBedrockProvider.swift:229`).
- **Other Anthropic provider-tool input schemas** (text_editor, computer, memory and others) were not ported.
- **Core limits.**
  - Tool order comes from a dictionary.
  - Finish reasons have no raw value.
  - An empty `stopSequences` cannot be told apart from an omitted one.
- **Documented divergences the platform does not require.**
  - Default region `us-east-1` and the `AWS_DEFAULT_REGION` fallback.
  - Call-level `citations`.
  - Credential errors raised at init.
  - Undocumented: `:message-type: error` frames surface as errors; upstream drops them.

#### Files changed
- `Sources/SwiftAIAmazonBedrock/`:
  - `AmazonBedrockLanguageModel.swift`
  - `AmazonBedrockShared.swift`
  - `BedrockStreamParsing.swift`
  - `AmazonBedrockProvider.swift`
  - `AmazonBedrockAnthropicLanguageModel.swift`
  - `AnthropicBedrockAdapter.swift`
  - `AmazonBedrockEmbeddingModel.swift`
  - `AmazonBedrockImageModel.swift`
- Tests: new `AmazonBedrockParityAuditTests.swift`; edited `AmazonBedrockTests.swift`, `AmazonBedrockUpstream5068Tests.swift`, `AmazonBedrockEventStreamParserTests.swift`.
- `Porting/map.json`
- `docs-site/scripts/provider-guides/amazon-bedrock.md`: namespace precedence, passthrough of unknown keys, `anthropicBeta`.

#### Tests
- `swift test --package-path Packages/swift-ai-amazon-bedrock --no-parallel`: 94 passed (was 65). Re-run after the Anthropic changes: 94 passed.

---

### @ai-sdk/anthropic-aws → swift-ai-anthropic-aws

#### Upstream test cases
55 in total: provider 26, fetch 26, region-validation 3.
- **Before this audit:** about 14 were covered (API-key and SigV4 auth, headers, user agent, threads, files/skills, region/baseURL).
- **Newly translated (2):** the credentialProvider-rejection wrapping test, and an empty-API-key SigV4 fallback test derived from the upstream provider source (not a translated upstream case).
- **Still missing:**
  - Fetch-wrapper input-shape cases: platform-only.
  - `new`-keyword and NoSuchModel type checks: platform-only.
  - Request-time missing-credential and missing-workspace errors: Swift throws at init.

#### Divergences fixed (`anthropic-aws-provider.ts:139-147`, `:156-166` → `AnthropicAWSProvider.swift`)
1. An empty `apiKey` or `ANTHROPIC_AWS_API_KEY` now falls back to SigV4. Before, it sent `x-api-key: ""`.
2. `credentialProvider` failures are wrapped as "AWS credential provider failed: … Please ensure your credential provider returns valid AWS credentials…".

#### Reported, not fixed
- The `AWS_DEFAULT_REGION` fallback is documented but not required by the platform.
- Missing region, workspace or credentials throw at init with `missingAPIKey`; upstream raises a load-setting error at request time.

#### Files changed
`Sources/SwiftAIAnthropicAWS/AnthropicAWSProvider.swift`, new `Tests/SwiftAIAnthropicAWSTests/AnthropicAWSParityAuditTests.swift`, `Porting/map.json`.

#### Tests
`swift test --package-path Packages/swift-ai-anthropic-aws --no-parallel`: 15 passed. Re-run after the Anthropic changes: 15 passed.

## Google and Google Vertex

## Parity audit: group `google`

Packages: `@ai-sdk/google` 4.0.121 → `Packages/swift-ai-google`; `@ai-sdk/google-vertex` 5.0.141 → `Packages/swift-ai-google-vertex`.
Upstream: `scratchpad/upstream-all/pkg/{google,google-vertex}/repo-src` (tests ref 0e8e0543).

Scope note: the brief asked to map every upstream `it` case. The upstream suites hold about 936 (google) and 278 (google-vertex) `it`/`it.each` declarations (~55k and ~13k lines). Subagent fan-out was not available (concurrency limit), so the audit went through the highest-risk paths by hand: the Gemini `generateContent` request builder, prompt conversion, tool preparation, response and stream parsing, provider factory and supported URLs, Vertex URL routing and metadata namespaces, and the Google/Vertex video parameters. Embedding, Imagen-on-Vertex, Cloud TTS/STT, MaaS/xAI/Anthropic-on-Vertex, Interactions and Realtime were only spot-checked or not reviewed (see "Not audited").

### @ai-sdk/google

Upstream test cases: ~936 `it` declarations (it.each expands further). Swift had 108 tests before this pass. Most of them are scenario tests and not 1:1 translations. Newly translated in this pass: 31 Swift tests in `UpstreamParityGoogleTests.swift`, covering ~40 upstream cases. One parameterized test covers all 7 cases of `should preserve the status of tool output $output`. Most upstream cases are still untranslated (see the end of this file).

#### Divergences

| # | Divergence | Upstream evidence | Swift evidence (before) | Verdict | User-visible effect |
|---|---|---|---|---|---|
| G1 | Non-content tool results were sent as the raw value in `functionResponse.response` instead of `{name, content}` (or `{name, error}`). Typed `text` outputs were sent as `{type, value}`. | convert-to-google-messages.ts:772-799; test :893-994 | GoogleGenerativeLanguageModel.swift (old :415-428) `"response": googleSerializeFunctionResponseContent(unwrappedOutput)` | fixed | Every ordinary tool result reached Gemini in a different wire shape. |
| G2 | Legacy (pre-Gemini 3) content tool results: one joined functionResponse, files after it, and the text always said "file". | convert-to-google-messages.ts:233-284; test :1467 | old googleGenerateContentToolResultContentParts | fixed | Request shape and order differed. |
| G3 | System messages were joined into one `systemInstruction` part with `\n`. A system message after a user message was accepted. Gemma joined them with `\n` instead of `\n\n`. | convert-to-google-messages.ts:338-348, 806-817, 819-824; tests :11-34, :422 | old generateContentBody `.joined(separator: "\n")` | fixed | Different systemInstruction parts. Invalid prompts were not rejected. |
| G4 | The missing-thoughtSignature warning was emitted once per call with different text. Upstream emits one warning per request: `Replayed N ... (tools: ...)`. | convert-to-google-messages.ts:819-835; test :2887 | old googleMissingThoughtSignatureWarning(toolName:) | fixed | Warning count and text. |
| G5 | Assistant `reasoningFile`, custom and approval parts were sent as `{text:""}`. Assistant URL files did not throw. Assistant data files had no thought flag or signature. Assistant tool results without server metadata were sent as functionResponse in the model turn. | convert-to-google-messages.ts:451-680 | old googleGenerateContentParts | fixed | Request body. |
| G6 | Server-tool results in tool messages were not moved onto the preceding model content. | convert-to-google-messages.ts:718-741; test :2382 | old tool-role conversion | fixed | Request body. |
| G7 | doGenerate merged thought text into `text`/content and dropped reasoning parts and per-part signatures (single-response path returned `content: []`). | google-language-model.ts:595-618; snapshot `reasoning-gemini3` | GoogleGenerateContentResultParsing.swift old :330-370 | fixed | `result.text` included thoughts. `result.reasoning` was empty. Thought signatures were lost on round trips. |
| G8 | doGenerate threw "No candidate text found…" on empty candidates. Upstream returns empty content with finish reason `other`. | google-language-model.ts:519-713 | old result() guard | fixed | Spurious errors (e.g. thinking models that stop at MAX_TOKENS with no candidates). |
| G9 | Finish reason counted provider-executed code execution and server tool calls as `tool-calls` (generate and stream). Upstream counts only client calls. | google-language-model.ts:712-716, 1529-1537 | old result / stream `sawToolCalls` | fixed | `tool-calls` instead of `stop`, which can loop agent steps. |
| G10 | Provider metadata omitted `promptFeedback`, `groundingMetadata`, `urlContextMetadata` and `safetyRatings` when absent. Upstream sends `null`. | google-language-model.ts:718-737, 1574-1608; snapshot | googleGenerateContentProviderMetadata / finalize | fixed | Metadata shape. |
| G11 | An empty signed text part in doGenerate became an extra `text("")` part. Upstream moves the signature onto the previous part. | google-language-model.ts:604-608 | googleJSONResponseToolContent | fixed | Extra empty content part. |
| G12 | The stream emitted tool-input-start/delta/end for code execution and server tool calls. Upstream emits only `tool-call`. | google-language-model.ts:1166-1176, 1315-1336 | GoogleGenerateContentStreamParsing.swift | fixed | Stream part sequence. |
| G13 | The model path was always `models/{id}`. Upstream uses `getModelPath`, so `tunedModels/x` becomes `.../tunedModels/x`. | get-model-path.ts; google-language-model.ts:768,888 | GoogleGenerativeLanguageModel.swift paths | fixed | Tuned models got a 404. |
| G14 | Gemini 2.5 penalties were sent on the Gemini API. Upstream drops them and warns `unsupported` for frequencyPenalty and presencePenalty. | google-language-model.ts:296-312, 410-416 | googleApplyStandardGenerationSettings | fixed | Request body and warnings. |
| G15 | `imageConfig.personGeneration`, `prominentPeople` and `imageOutputOptions` were sent to the Gemini API without a warning. | google-language-model.ts:261-288 | googlePrepareGenerateContentOptions | fixed | The API rejects these fields. |
| G16 | Combined provider and function tools on Gemini 3 with toolChoice `auto` sent `AUTO`. Upstream keeps `VALIDATED`. | google-prepare-tools.ts:212-218; test :642 | GoogleToolPreparation.swift | fixed | toolConfig. |
| G17 | `strict: true` was sent inside `parametersJsonSchema`. | google-prepare-tools.ts:318-327 | googleFunctionDeclarations | fixed | Schema body. |
| G18 | The vertex_rag_store warning text lacked `(providerID)` and came last. Warning order did not follow upstream (request → prompt → reasoning → tools). | google-language-model.ts:183-198, 337-345, 452 | googlePrepareTools | fixed | Warning text and order. |
| G19 | `generationConfig` was omitted when empty. Upstream always sends the object. | google-language-model.ts:404 | generateContentBody | fixed | Body. |
| G20 | The JSON response tool gate was `(^|[/.])gemini-`. Upstream uses `(^|/)gemini-`. | google-model-catalog.ts:244 | googlePrepareJSONResponseToolRequest | fixed | Model-id gate. |
| G21 | `supportedURLs` was empty, so core downloaded YouTube, Files API and https file URLs instead of passing them as `fileData`. | google-provider.ts:241-310 | GoogleBatchLanguageModel / GoogleGenerativeLanguageModel | fixed | YouTube and Files URLs failed or were mangled. |
| G22 | The user-agent `ai-sdk-google/…` was only added when `name` was the default. | google-provider.ts:271-285 | GoogleGenerativeAIProvider.swift | fixed | Missing UA with a custom name. |
| G23 | Video provider options did not override standard parameters (seed, resolution, sampleCount). Upstream copies options over them. | google-video-model.ts:212-263 | googleVideoParameters | fixed | Option precedence. |
| G24 | `$ref` serialization and JSON text fallbacks escaped `/`. `JSON.stringify` does not. | convert-to-google-messages.ts:96-108 | googleJSONString | fixed | Serialized text. |
| G25 | Provider references: a missing `google` key fell back to the first value or `""` instead of throwing. Gemini 3 file parts carried no `mimeType` unless videoMetadata was set. | convert-to-google-messages.ts:399-413 | old providerReference case | fixed | Request validity. |
| G26 | Imagen (`:predict`) is still supported. Upstream 4.0.121 throws "Google image models other than Gemini are no longer supported." | google-image-model.ts:93-97 | GoogleGenerativeMediaModels.swift:126-187 | reported (documented in provider-guides/google-generative-ai.md:30,149) | Swift accepts models that upstream rejects. |
| G27 | Gemini image: Swift throws on `count > 1` and on "No Gemini image inlineData found". Upstream uses maxImagesPerCall=1 (core batches) and returns `[]`. | google-image-model.ts:58-63, 227-236 | GoogleGenerativeMediaModels.swift:240-300 | reported (core has no image batching by maxImagesPerCall) | Errors where upstream succeeds. |
| G28 | User `imageURL` parts carry no `mimeType` in `fileData`. | convert-to-google-messages.ts:378-392 | core `AIContentPart.imageURL` has no media type | platform/core limitation, reported | Wire field missing. |
| G29 | Function declaration order follows a Swift dictionary (`LanguageModelRequest.tools` is unordered). | prepare-tools order | core | core limitation, reported | Declaration order is nondeterministic. |
| G30 | API key fallback env vars `GOOGLE_API_KEY` and `GEMINI_API_KEY`. Upstream uses only `GOOGLE_GENERATIVE_AI_API_KEY`. | google-provider.ts:276-280 | GoogleGenerativeAIProvider.swift:14 | reported (extra fallback; documented in the capability matrix?) | Picks up keys upstream would ignore. |
| G31 | Stream emits `responseMetadata` before `streamStart`, even without a responseId. | google-language-model.ts:1043-1080 | GoogleGenerateContentStreamState.apply | platform convention (shared stream adapter), not changed | Part order. |
| G32 | Generated IDs are deterministic (`tool-call-N`, `google-code-execution-N`) instead of generateId(). Server tool results set `dynamic: true`. | — | parsing | platform-acceptable / minor | Opaque IDs. |

### @ai-sdk/google-vertex

Upstream test cases: ~278. Swift had 49 tests. Newly translated: 7 tests in `UpstreamParityVertexTests.swift`, which cover provider-base tuned-endpoint cases (2), the vertex-language-model model-path case, metadata namespaces, supported URLs, reference rejection and namespace precedence. Two existing tests were corrected to upstream expectations: the tuned endpoint URL and the server-tool finish reason.

| # | Divergence | Upstream evidence | Swift evidence | Verdict | Effect |
|---|---|---|---|---|---|
| V1 | Gemini provider metadata (result, parts, stream, finish) was written under `google`. Upstream writes it under both `googleVertex` and `vertex`. | google-language-model.ts:174-180, 525-528 (providerOptionsNames) | GoogleVertexModels.swift (shared parser) | fixed (`googleProviderMetadata(_:namespaces:)` + `transformPart`) | Grounding, usage and signatures are now found under the documented Vertex keys. |
| V2 | Tuned `endpoints/…` URL was `.../locations/r/models/endpoints/id`. Upstream is `.../locations/r/endpoints/id`. An explicit `baseURL` lost its `/publishers/google` suffix. | provider-base.ts:262-289; test :361,:396 | GoogleVertexModels.swift path; GoogleVertexProvider.swift endpoint URL | fixed | Tuned models got a 404. |
| V3 | No `supportedURLs`, so core downloaded http(s) URLs and failed on `gs://`. Upstream supports `^https?://` and `^gs://`. | provider-base.ts:327-334 | GoogleVertexLanguageModel | fixed | gs:// image parts failed. |
| V4 | Thought signatures and server-tool metadata read `google` first. Upstream reads `googleVertex`, then `vertex`, then the `google` fallback. Provider references were accepted although upstream throws on Vertex. | convert-to-google-messages.ts:323-336, 396-404; test :202 | googleThoughtSignature(from:) | fixed | Wrong signature replayed. |
| V5 | All shared Gemini request and response fixes G1–G25 now also apply to Vertex, which uses the single shared `googleGenerateContentCall`. The duplicated Vertex body builder was removed. | — | GoogleVertexModels.swift | fixed | — |

Umbrella read-only findings (not fixed):
- `Sources/SwiftAISDK/Providers/GoogleCompatibility.swift:8-19`: `GoogleGenerativeAIProvider(settings:)` builds headers with `OpenAICompatibleProvider.buildHeaders`, so the `ai-sdk-google/4.0.121` user agent is probably not added. It also uses the extra env vars from G30.
- `ProviderCapabilityMatrix.swift:65` advertises "Gemini and Imagen images", which matches G26.
- Root compatibility tests assert pre-fix behavior. Running `node Scripts/sdk.mjs dev test --filter "Google|google|Vertex|vertex|Gemini|gemini"`: 143 tests, 17 tests and 23 issues fail. All of the failures come from the three intended fixes:
  - V1 namespace (`providerMetadata["google"]` on Vertex): WeeklyGoogle20261018Tests :40, :42, :67, :141; WeeklyGoogle20261023Tests :80-82, :94, :96, :133, :143-144; WeeklyGoogle20261011Tests :34; GoogleVertexTests :158.
  - G9 finish reason: GoogleGenerativeAIMediaAndToolsTests :275, :334.
  - G1 tool envelope: GoogleVertexTests :333 (`response.answer` is now `response.content.answer`).

  These root tests need their expectations updated. No root test failed for any other reason.

### Files changed

- swift-ai-google
  - New: `Sources/SwiftAIGoogle/GoogleGenerateContentPrompt.swift` (upstream `convertToGoogleMessages`), `GoogleProviderMetadataNamespace.swift`, `Tests/SwiftAIGoogleTests/UpstreamParityGoogleTests.swift`.
  - Modified: `GoogleGenerativeLanguageModel.swift`, `GoogleGenerationOptions.swift`, `GoogleTools.swift` (additive `requestWarnings`/`reasoningWarnings`), `GoogleToolPreparation.swift`, `GoogleGenerateContentResultParsing.swift`, `GoogleGenerateContentStreamParsing.swift` (additive `transformPart:` parameter), `GoogleGenerateContentMetadata.swift`, `GoogleBatchLanguageModel.swift`, `GoogleGenerativeAIProvider.swift`, `GoogleGenerativeMediaOptions.swift`, `Tests/.../Weekly20261108GoogleTests.swift`, `Porting/map.json`.
- swift-ai-google-vertex
  - Modified: `GoogleVertexModels.swift`, `GoogleVertexProvider.swift`, `Tests/.../GoogleVertexMediaAndMaaSTests.swift`, `Porting/map.json`.
  - New: `Tests/.../UpstreamParityVertexTests.swift`.
- `docs-site/scripts/provider-guides/google-vertex.md`: metadata namespaces, supported URLs, provider references.

Public API: only additive changes (`googleModelPath`, `googleGenerateContentCall`, `googleProviderMetadata(...)`, the `transformPart:` defaulted parameter, the `requestWarnings`/`reasoningWarnings` fields, `supportedURLs` on the language models). `googleGenerateContentMessageJSON` keeps its signature.

### Test results

- `swift test --package-path Packages/swift-ai-google --no-parallel`: 138 tests passed (108 before this pass).
- `swift test --package-path Packages/swift-ai-google-vertex --no-parallel`: 56 tests passed (49 before this pass).

### Not audited or still missing (reason)

Most upstream cases remain untranslated. All of them are Swift-reachable unless noted.
- google-language-model.test.ts (235): only the request and generate/stream cases above. Snapshot-level stream sequences (partial-arg accumulator, nested args) were not compared field by field.
- google-json-accumulator (49), google-files (25), google-batch (25), google-decision (17), google-embedding (17), google-image (13), google-speech (30+5), google-video (24; only parameter precedence checked).
- Interactions (~200 cases) and Realtime (~94 cases): not reviewed.
- transcription and speech-translation: Swift does not expose these products (documented gap).
- Vertex: embedding (16), image (10), video (25), Cloud TTS (16), transcription (18) and Gemini transcription (13) were spot-checked only. Vertex video option precedence already matches upstream.
- Anthropic, MaaS and xAI on Vertex (~70 cases): not reviewed.
- Auth: edge auth and google-auth-library tests are JS-platform-only.

Unsure:
- `googleVideoURLWithAPIKey` with `apiKeyProvider` may append the credential placeholder instead of the resolved key.
- Removing `google` from Vertex metadata could break Swift consumers who read `providerMetadata["google"]` on Vertex. This change is intentional for upstream parity.

## Gateway and MCP

## gateway-mcp parity report

Sections: gateway core, gateway media, MCP.

## gateway-mcp — `@ai-sdk/gateway` 4.0.146 core half (provider, language model, decision, errors, metadata, tools)

Upstream: `upstream-all/pkg/gateway/npm/src` (4.0.146) and `repo-src` (matching-release tests).
Swift: `Packages/swift-ai-gateway`.

### Upstream test cases (it/it.each lines)

| Upstream test file | Cases | Already translated (est.) | Newly translated | Still missing / reason |
| --- | ---: | ---: | ---: | --- |
| gateway-language-model.test.ts | 65 | ~8 | 22 | Uint8Array image/file encoding (6+6+3: JS-only, Swift always base64-encodes `Data`), `new` keyword/constructor props, `fetch` signal identity (covered by Weekly20261101 cancellation tests), provider-options passthrough (covered by existing body tests), "already a Date" timestamp |
| gateway-provider.test.ts | 72 | ~15 | 7 | JS `new`/default export/mocked-constructor cases (platform), getGatewayAuthToken table (Swift resolves at init — see reported item R1), OIDC mock cases (`@vercel/oidc` is Node-only) |
| gateway-fetch-metadata.test.ts | 37 | ~4 | 7 | strict schema rejection (`malformed response data`, invalid pricing) — Swift is lenient (R6); custom fetch (platform) |
| gateway-decision-model.test.ts | 30 | ~22 (earlier weekly passes) | 0 | network-error mapping fixed here; body/answer cases reviewed only at source level |
| errors/*.test.ts (create 35, as 17, extract 15, types 32, parse-auth 17) | 116 | ~20 | 6 (through model/provider paths) | class-hierarchy/`isInstance`/marker tests are JS-only; `validationError`, forbidden `ruleId` need core type changes (R3) |
| gateway-generation-info.test.ts | 14 | ~4 | 0 | strict schema rejection (lenient defaults, R6) |
| gateway-spend-report.test.ts | 15 | ~5 | 0 | strict schema rejection (R6); URLSearchParams encoding (R7) |
| gateway-provider-options.test.ts | 11 | ~8 | 0 | decision options schema reviewed in earlier pass |
| tool/*.test.ts (tako 8, parallel 12, browserbase 11, deepseek 12, tool-error 1) | 44 | ~15 | 1 (exaSearch, no upstream test) | zod input/output schema validation tests (schemas are not exposed on Swift provider tools) |
| vercel-environment.test.ts, lazy-schemas.test.ts | 6 | 0 | 0 | Node-only (`@vercel/oidc` request context, lazy zod) |

### Divergences

| # | Upstream evidence | Swift evidence (before) | Verdict | User-visible effect |
| --- | --- | --- | --- | --- |
| 1 | `gateway-language-model.ts:59-67` body = V4 call options; ai `convert-to-language-model-prompt.ts` (system string content, `tool-call.input`, `tool-result.output`, `providerOptions`, image → `mediaType:'image'`) | `GatewayModels.swift` `gatewayLanguageBody` sent `args`/`result`, system as array, no `responseFormat`, no part/message `providerOptions`, `custom.value`, approval requests as empty text | **fixed** (`GatewayLanguageWire.swift`) | Multi-turn tool conversations, structured output (`responseFormat`), Anthropic cache control and other per-part options were sent in a shape Gateway does not read. |
| 2 | V4 `finishReason {unified,raw}`, nested `usage`, `response {id,timestamp,modelId}` (passthrough at `gateway-language-model.ts:96-101`) | `generate` read string `finishReason`, OpenAI-style `usage`, top-level `id/model` | **fixed** | Real Gateway results had nil finish reason, empty usage and no response id/model. |
| 3 | `generate` returns any content; no "no text" error | Swift threw `invalidResponse` when no text/tool calls | **fixed** | Reasoning-only / file-only / empty results failed. |
| 4 | Stream passthrough (`gateway-language-model.ts:146-174`): `error` parts forwarded, `raw` only `rawValue` when requested, `response-metadata` forwarded with Date timestamp, V4 `text-start/end`, `tool-call` after `tool-input-end`, `file`, `custom`, `tool-approval-request` | Swift ignored `error`, `response-metadata`, file/custom/approval parts; yielded every SSE event as `.raw`; emitted the tool call at `tool-input-end` AND again for the following `tool-call` part; finish reason/usage not read from V4 objects | **fixed** | Mid-stream provider errors were silently dropped; tool calls were duplicated on real V4 streams; raw chunks were noisy; usage/finish missing. |
| 5 | `includeRawChunks` is part of the streamed call options | not sent | **fixed** | — |
| 6 | `GatewayAuthenticationError.createContextualError` (`errors/gateway-authentication-error.ts`, `create-gateway-error.ts:70-77`) | raw server message | **fixed** (`GatewayErrors.swift`, all HTTP paths pass `config.authMethod`) | Auth failures now carry Gateway's credential-specific guidance. |
| 7 | `create-gateway-error.ts:48-62`: invalid envelope → `"Invalid error response format: Gateway request failed"`, raw string kept as `response`, `generationId` still recovered | message embedded the body; empty body → nil response; generationId dropped | **fixed** | Message/response match upstream. |
| 8 | `as-gateway-error.ts:79-89` thrown non-API errors → `GatewayResponseError` "…Gateway request failed: <message>" (500, retryable) | language model leaked raw `URLError`; decision/getToken produced `internalServerError` with `String(describing:)` | **fixed** (`gatewayTransportError`) | Network failures are now typed Gateway errors (still retryable via `AIError.gateway`). |
| 9 | `getHeaders` wraps credential failures in "No authentication provided" (`gateway-provider.ts:399-410`) | blank `apiKeyProvider` key surfaced `AIError.invalidArgument` | **fixed**; updated `Weekly20261101CancellationTests.blankCredentialCallbackFailsBeforeSending` | — |
| 10 | `createO11yHeaders` (`gateway-provider.ts:466-495`) | never sent | **fixed** (deployment id, env, region, project id); request id is **platform-only** (Node request context) | Vercel observability headers now reach Gateway. |
| 11 | metadata cache 5 min, `metadataCacheRefreshMillis`, stale-while-revalidate (`gateway-provider.ts:515-546`) | refetched every call | **fixed** (`GatewayMetadataCache`, new `metadataCacheRefreshMillis` setting) | — |
| 12 | `gateway-fetch-metadata.ts:124-171` known-modelType filter, `pricing` (cache fields renamed), `description` | not filtered, not exposed | **fixed** (additive `GatewayModelEntry.description/pricing/specificationVersion`, `GatewayModelPricing`) | — |
| 13 | team header precedes `...options.headers` (`gateway-provider.ts:388-397`) | `teamIDOrSlug` overwrote a custom team header | **fixed** | — |
| 14 | `gateway-tools.ts` exports `exaSearch` (`gateway.exa_search`) | missing | **fixed** (`GatewayTools.exaSearch`) | — |
| 15 | text extraction only from text parts | `parseGatewayText` concatenated reasoning text into `text` | **fixed** | — |

#### Reported, not fixed

- **R1 credential timing**: Swift resolves api-key vs OIDC at `GatewayProvider.init` and throws `AIError.missingAPIKey` there when neither exists; upstream never throws at creation and resolves per request (and switches `ai-gateway-auth-method` per request). Needs a credential-resolver redesign (`GatewayProvider.swift` `gatewayAuthToken`).
- **R2 error wrapping inconsistency**: language/media/metadata paths throw `AIError.gateway(GatewayError)`, while `GatewayDecisionModel` and streaming speech/transcription terminal errors throw bare `GatewayError`. Core `isRetryable` (`swift-ai-core/Sources/SwiftAI/AIRetryRuntime.swift:488-505`) only recognizes `AIError.gateway`, so bare Gateway 5xx/429 errors are not retried. Changing the thrown type would break callers that catch `GatewayError`.
- **R3 core error type**: `GatewayError` has no forbidden `ruleId` or `validationError`; `timeout_error` in a response envelope maps to `.timeoutError` (upstream: internal server error); Swift additionally accepts a `{type:"error", errorType}` envelope upstream rejects.
- **R4 provider-tool name**: provider tools use the tool's own `name` instead of the request's tools-dictionary key (upstream uses the key).
- **R5 stream termination**: Swift stops reading after `finish` and always synthesizes a `finishMetadata` (reason `other` when the server sent none, e.g. after a mid-stream error); upstream forwards only the server's parts.
- **R6 lenient parsing**: catalog, credits, generation info and spend report accept missing/invalid fields with defaults where upstream throws a response error.
- **R7 query encoding**: spend report and generation info use `URLComponents` encoding instead of `URLSearchParams`/`encodeURIComponent` (differs only for `+`, `/`, `?` etc.).
- **R8 body `headers`**: the body now carries call `headers` like upstream, but upstream's also include the `ai/x.y.z` user agent added by `generateText`.
- **R9 umbrella**: `Sources/SwiftAISDK/GatewayErrors.swift` calls the public 3-argument `gatewayErrorFromHTTPStatus`, so authentication errors there get the "No authentication provided" text (upstream's message when the auth method is unknown). `Sources/SwiftAISDK/Providers/*` otherwise only forward to `GatewayProvider`.
- Platform-only relied on: no `ai-o11y-request-id`; `Data` is always base64 (no Uint8Array path); bridged `AIError.gateway` wrapper instead of a class hierarchy.

### Files changed (core half)

- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayLanguageWire.swift` (new)
- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayModels.swift` (language generate/stream, `exaSearch`, authMethod on batch errors, helper visibility)
- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayErrors.swift`, `GatewayConfiguration.swift`, `GatewayProvider.swift`, `GatewayParsing.swift`, `GatewayDecisionModel.swift`, `GatewayMediaModels.swift`/`GatewayStreamingSpeechModel.swift` (authMethod only)
- `Packages/swift-ai-gateway/Tests/SwiftAIGatewayTests/ParityAuditCoreTests.swift` (new, 24 tests), `Weekly20261101CancellationTests.swift` (updated expectation)
- `Packages/swift-ai-gateway/Porting/map.json`, `docs-site/scripts/provider-guides/gateway.md`

### Test results

`swift test --package-path Packages/swift-ai-gateway --no-parallel`: 115 tests in 15 suites passed (91 before this half).
`swift test --package-path Packages/swift-ai-mcp --no-parallel`: 186 tests in 8 suites passed.
docs-site check/build not run (disk nearly full; npm ci not possible).
Note: deleted the regenerable build cache `Packages/swift-ai-gateway/.build/agent-gateway-media` created by this group's sub-agent after the volume hit ENOSPC.

## gateway-mcp — `@ai-sdk/gateway` 4.0.146 media / batch / realtime half

Scope: gateway-image-model, gateway-video-model, gateway-speech-model (+ speech-model-stream test),
gateway-transcription-model, gateway-embedding-model, gateway-reranking-model, gateway-realtime-model,
gateway-realtime-auth, gateway-batch (+ their *-settings.ts). Swift package `Packages/swift-ai-gateway`.
Upstream: `upstream-all/pkg/gateway/npm/src` (4.0.146) and `repo-src` (tests @ 0e8e0543).

### Upstream test cases (it/it.each lines; it.each counted once)

| Upstream test file | Total | Already translated (before) | Newly translated | Still missing (reason) |
|---|---|---|---|---|
| gateway-image-model.test.ts | 50 | ~5 (all-params body, files/mask, seed 0, client-option strip) | ~24 (omit optionals, all params, seed 0, usage x3, retryability, warnings deprecated/unsupported/other/mixed/empty, provider metadata, response metadata, header merge, abort signal, 400/401 errors, provider options, empty provider options, model id, Uint8Array files/mask/mixed/URL encoding, strip option true/false x3 cases) | constructor/maxImagesPerCall + custom provider name (no public field on Swift model); string-data passthrough (ImageInputFile holds bytes only — platform); file `providerOptions` (core `ImageInputFile` has no field — reported); 7 binary-decoding cases (64 KiB `Uint8Array` results, chunked body) — platform: `ImageGenerationResult` is base64 strings; "reject non-string images" (Swift silently drops — reported); o11y headers (reported to parent) |
| gateway-video-model.test.ts | 51 | ~9 (frameImages, inputReferences, SSE error, uploaded videos, start/webhook/completed/cancelled) | ~16 (omit optionals, all params, seed 0, falsy omission, SSE error msg+status, heartbeat comments, empty SSE, start full body+callbackUrl, start omits optionals/no callbackUrl, idempotency key forwarded/absent, status pending/error/cancelled, start warnings/metadata) | constructor (no public field); string-data passthrough (platform); image `providerOptions` (core); o11y headers (parent); `handleWebhookOption` identity (covered by existing async test) |
| gateway-speech-model.test.ts | 9 | 1 (token route) | 6 (headers, body all options, omit optionals, extract audio/metadata, 400/500 typed errors, URL) | o11y (parent); browser getToken rejection (platform) |
| gateway-speech-model-stream.test.ts | 13 | ~9 (envelope, split voice/providerOptions, team subprotocol, typed error part, audio projection, close w/o finish, Abort/Timeout, empty part, cancel, URL, splitTextDelta) | 2 (close message text/type, untyped error part on close) | none Swift-reachable |
| gateway-transcription-model.test.ts | 40 | ~14 (streaming parity file, words, timestamp warning, cancellation) | ~9 (byte audio body, omit providerOptions, extract fields, default optional fields, durationInSeconds not derived, timestamp warning exact list + empty, xAI/spacexAI diarization warn + not-warn, close w/o finish type/message, untyped/string/object error payloads) | string-audio passthrough (Swift API takes `Data` — platform); header-capable WebSocket / undefined-header stripping (platform transport); browser getToken rejection (platform); o11y (parent) |
| gateway-embedding-model.test.ts | 13 | 1 (endpoint/usage/providerOptions) | 10 (dimensions with/without providerOptions, headers, usage, warnings, default warnings, values array, providerOptions omission, 400/500 errors, providerMetadata in raw body and top level) | o11y (parent) |
| gateway-reranking-model.test.ts | 13 | 1 (endpoint/topN/providerOptions) | 9 (headers, ranking, warnings, default warnings, body, omit topN, response headers, provider metadata, 400/500 errors, URL) | o11y (parent) |
| gateway-realtime-model.test.ts | 20 | ~8 (intent rejection, mint URL/body/auth, expiresAt, ws URL, server headers/team, codec) | 1 (provider team scope round-trips through protocols) | identity-codec pass-through (`toBe` same object) — platform: Swift uses typed `AIRealtime*` events; browser guards (platform) |
| gateway-realtime-auth.test.ts | 12 | 0 (no public API existed) | 12 | none |
| gateway-batch.test.ts | 33 | ~8 (start wire/idempotency/callbackUrl/file base64, status partial counts + 404, results chunked NDJSON + revival, line limit) | ~9 (status/cancel/results post batchId without `ai-model-id`, custom headers, cancel ack with/without metadata, skip empty lines, 400 non-terminal → invalid request, cancel 404 → not found, single request) | unsupported request type error class (`UnsupportedFunctionalityError` has no core equivalent — reported); fetch `signal` identity and DOMException identity (covered generically by Weekly20261101CancellationTests; Swift passes `AIAbortSignal`, platform) |

### Divergences

| # | Upstream evidence | Swift evidence (before fix) | Verdict | User-visible effect |
|---|---|---|---|---|
| 1 | gateway-image-model.ts:113-128 body `n` always + `providerOptions` when truthy; ai generate-image.ts:90,219 (`n = 1`, `providerOptions ?? {}`); test image:146-170 expects `{prompt, n:1, providerOptions:{}}` | GatewayMediaModels.swift image body omitted `n` when count nil and omitted empty providerOptions | **fixed** (GatewayMediaModels.swift:64-83) | Wire body now `{prompt, n:1, providerOptions:{}}` |
| 2 | gateway-image-model.ts:78-93 strips `experimental_streamingImageDecoding` only when present; removes emptied gateway; drops providerOptions when empty | Swift stripped any `gateway` object (so `gateway: {}` was dropped) | **fixed** | `providerOptions.gateway: {}` forwarded unchanged; stripping semantics identical |
| 3 | gateway-image-model.ts:116-117 `size &&`, `aspectRatio &&` | Swift sent empty strings | **fixed** | `""` size/aspectRatio omitted |
| 4 | gateway-image-model.ts:153-159 returns `usage` when present | Swift never set `ImageGenerationResult.usage` | **fixed** (`gatewayImageUsage`, GatewayMediaModels.swift:113) | `result.usage` = input/output/total tokens |
| 5 | gateway-image-model.ts:133 passes `abortSignal` | Swift image call did not pass `request.abortSignal` | **fixed** | Image requests are now cancellable via abort signal |
| 6 | gateway-video-model.ts:347-375 `n`, falsy aspectRatio/resolution/duration/fps omitted, `providerOptions` (always `{}` via generate-video.ts:358); tests video:191-222, 1318-1333 | Swift omitted `n`/empty providerOptions, sent `0`/`""` values | **fixed** (`gatewayVideoBody`, GatewayMediaModels.swift:283) | generate and `/video-model/start` bodies match `{prompt, n:1, providerOptions:{}}` |
| 7 | gateway-speech-model.ts:90-97 `voice &&`, `outputFormat &&`, `instructions &&`, `language &&` | Swift sent empty strings | **fixed** | `""` options omitted |
| 8 | gateway-transcription-model.ts:149 `durationInSeconds ?? undefined`; test transcription:292-304 | Swift fell back to `duration` alias then max segment end | **fixed** (GatewayMediaModels.swift:455) | `durationInSeconds` is nil unless the Gateway reports it |
| 9 | gateway-stream-errors.ts:57-78 (`not_found` absent from SERVER_ERROR_STATUS_CODES; untyped → `Error("AI Gateway transcription stream failed: …")`), errors/as-gateway-error.ts:82-91 + create-gateway-error.ts:47-61 (plain Error → `GatewayResponseError` "Invalid error response format: Gateway request failed: …", 500) | GatewayStreamingTranscriptionModel.swift mapped `not_found`→404 and unknown→`internalServerError` with raw message; close / connection errors were `internalServerError` | **fixed** (GatewayStreamingTranscriptionModel.swift:710-745, close paths ~290-310); existing Swift test `gatewayStreamingTranscriptionMapsNotFoundTerminalError` updated to upstream | Terminal error type `.responseError` (500) with upstream message for untyped/`not_found` parts, close-without-finish and connection errors |
| 10 | gateway-speech-model.ts:395-410 close message `AI Gateway speech stream closed before a finish part was received (code N[: reason]).` wrapped by asGatewayError; untyped error part → GatewayResponseError | Swift surfaced core `AIStreamingSpeechError("Speech stream closed before completion …")` and plain `AIStreamingSpeechError` for untyped parts; connection errors `internalServerError` | **fixed** (`speechGatewayConnectionError`, `gatewayStreamResponseError`, GatewayStreamingSpeechModel.swift:120-160); Weekly speech test expectation updated | Speech stream terminal errors are `GatewayError(.responseError, 500)` with upstream text |
| 11 | gateway-provider.ts:478 `asGatewayError` for speech mint transport failures | Speech `getToken` transport failure reported as "Connection error on AI Gateway speech stream" | **fixed** (GatewayStreamingSpeechModel.swift getToken catch) | Message `Invalid error response format: Gateway request failed: <error>` |
| 12 | gateway-batch.ts:117-125 etc. all batch errors via `asGatewayError` (tests batch:364-389, 459-479, 563-575, 763-786) | `GatewayBatchProvider` (providerID `gateway.batch`) called `gatewayAPICallError(provider: providerID)`, whose `provider == "gateway"` check failed → generic `AIAPICallError` | **fixed** (GatewayModels.swift `GatewayBatchProvider` only: 4 call sites now pass `config.providerID`) | `experimentalBatch()` start/status/results/cancel HTTP errors are `AIError.gateway(GatewayError)` (e.g. `.notFound`, `.invalidRequestError`) |
| 13 | index.ts exports `getGatewayRealtimeProtocols`/`…Transcription…`/`…Speech…`, `getGatewayRealtimeAuthToken`, `getGatewayRealtimeTeamIdOrSlug`, subprotocol constants (gateway-realtime-auth.ts) | no public Swift equivalent | **fixed (additive API)** `GatewayRealtimeAuth` (new GatewayRealtimeAuth.swift) | Clients/servers can build and decode Gateway WebSocket auth subprotocols |
| 14 | gateway-provider.ts:500-523 o11y headers (`ai-o11y-deployment-id/environment/region/request-id/project-id`) sent by every model | no o11y headers anywhere in the package | **reported** (provider config, parent scope) | Vercel deployments lose Gateway observability attribution |
| 15 | errors/gateway-authentication-error.ts:37-85 contextual auth messages by auth method (HTTP + stream error parts via create-gateway-error.ts:69-76) | GatewayErrors.swift and stream mappers keep raw server message | **reported** (errors/*, parent scope) | 401 messages differ from upstream guidance text |
| 16 | gateway-provider.ts:475-478 (mint transport failure → asGatewayError) | GatewayProvider.swift:191-199 transcription `getToken` wraps as `GatewayError(.internalServerError, String(describing: error))` | **reported** (file owned by parent). Proposed: replace with `throw gatewayStreamResponseError(String(describing: error))` | Type `.internalServerError` vs upstream `response_error`, message lacks prefix |
| 17 | gateway-image-model.ts:233-245 schema (`images` strings, else `GatewayResponseError`); test image:1260 | Swift `compactMap` drops non-string images, accepts `data`/`b64_json`/`url` aliases; embedding/rerank/speech also lenient (aliases `results`, `relevance_score`, `provider_metadata`, `duration`) | **reported** (no fix: cross-cutting response-validation policy) | Malformed Gateway responses silently degrade instead of throwing |
| 18 | gateway-image-model.ts:69-91 option is client-only; no warning | Swift adds `unsupported` warning `gateway.experimental_streamingImageDecoding` when `true` (documented in provider guide + map.json) | **documented-intentional, reported** — not platform-required (result images are equivalent base64) | Extra warning in `result.warnings` |
| 19 | gateway-image-model.ts:189-197 / gateway-video-model.ts:381-389 forward file `providerOptions` | core `ImageInputFile` has no providerOptions | **reported** (core API) | Per-file provider options cannot be sent |
| 20 | gateway-batch.ts:300-313 `UnsupportedFunctionalityError` (`functionality: 'batch request type: image'`) | GatewayModels.swift GatewayBatchProvider throws `AIError.invalidArgument` | **reported** (core has no generic UnsupportedFunctionalityError) | Different error type; message text matches |
| 21 | gateway-batch.ts:62-80 (no top-level `modelId`; status/results/cancel without `ai-model-id`) | GatewayModels.swift:673 `GatewayLanguageModel` (Swift-only `BatchLanguageModel` path) adds top-level `modelId` and sends `ai-model-id` on status/results | **reported** (Swift-only compatibility path in language-model file; upstream has no model-bound batch) | Extra wire field/header on the legacy path only; `experimentalBatch()` matches upstream |
| 22 | ai transcribe.ts:56 / generate-speech.ts:60 default `providerOptions = {}` → Gateway sends `providerOptions: {}`; model-level tests (speech:105, transcription:213) expect omission | Swift omits empty providerOptions for speech/transcription | **unsure / not changed** (matches the upstream model-level tests; e2e via facade would send `{}`) | Absent vs `{}` key |
| 23 | gateway-video-model.ts:518-525 start `operation: z.unknown()` | Swift throws when `operation` missing | reported (minor) | Edge only |
| 24 | gateway-realtime-model.ts:96-103 team subprotocol only from `teamIdOrSlug` | GatewayRealtimeModel.swift:26 derives it from the `x-vercel-ai-gateway-team` header (also set by custom headers) | reported (minor) | Custom-header team also scopes the browser handshake |

Platform-only differences relied on: Swift typed realtime events instead of identity codec; `AIWarning` has no `details`
field (upstream `details` mapped into `message`); base64 image strings instead of `Uint8Array`; `Data` audio inputs;
`AIAbortSignal`/`CancellationError` instead of DOMException; browser-environment guards absent.

Umbrella (`Sources/SwiftAISDK/**`, read-only): Gateway entries are thin re-exports (ProviderRegistry.swift:85-104,
GatewayCompatibility.swift, ProviderCapabilityMatrix.swift:62); no media divergence found.

### Files changed

- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayMediaModels.swift` (image/video/speech/transcription bodies, image usage + abort)
- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayStreamingSpeechModel.swift` (stream/mint error mapping, shared `gatewayStreamResponseError`)
- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayStreamingTranscriptionModel.swift` (error-part / close / connection mapping)
- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayModels.swift` (GatewayBatchProvider error provider id only)
- `Packages/swift-ai-gateway/Sources/SwiftAIGateway/GatewayRealtimeAuth.swift` (new, additive public API)
- `Packages/swift-ai-gateway/Tests/SwiftAIGatewayTests/ParityAuditMediaTests.swift` (new)
- `Packages/swift-ai-gateway/Tests/SwiftAIGatewayTests/GatewayStreamingTranscriptionUpstreamParityTests.swift` (not_found expectation → upstream)
- `Packages/swift-ai-gateway/Tests/SwiftAIGatewayTests/WeeklyGatewaySpeech20261025Tests.swift` (close message expectation → upstream)
- `Packages/swift-ai-gateway/Porting/map.json` (registered new source + test file)
- `docs-site/scripts/provider-guides/gateway.md` (GatewayRealtimeAuth helpers)

### Test results

`swift test --package-path Packages/swift-ai-gateway --no-parallel --scratch-path Packages/swift-ai-gateway/.build/agent-gateway-media`
→ 91 tests in 12 suites passed (Swift Testing; parameterized tests counted once), 0 failures.

## Parity audit: `@ai-sdk/mcp` 2.0.99 -> `Packages/swift-ai-mcp`

Upstream: `pkg/mcp/npm/src` (identical to `repo-src` at test ref 8bc7652c; verified file-by-file).
Umbrella: `Sources/SwiftAISDK/ProviderExports.swift` only re-exports `SwiftAIMCP`; no reimplemented MCP logic, no divergence there.

### Upstream test cases (it / it.each counted once)

| Upstream file | Cases | Already translated (est.) | Newly translated | Still missing (reason) |
| --- | ---: | ---: | ---: | --- |
| tool/mcp-client.test.ts | 94 | ~35 | ~27 | ~32: prototype-named tools/`Object.create(null)` (JS-only), TS type inference/`expectTypeOf`, duck-typed invalid transport, deprecated `name` option (no Swift API), getter-only `protocolVersion` transports (JS), fake-timer internals (`responseHandlers.size`), several snapshot variants already covered by equivalent Swift assertions |
| tool/mcp-http-transport.test.ts | 33 | ~12 | 6 | ~15: `redirect`/custom `fetch` (mapped to `followRedirects`/`AITransport`, asserted), rejected `reader.cancel` after stream error (JS streams), OAuth dedupe across inbound GET+initialize (Swift coordinator tested separately), fake-timer variants |
| tool/mcp-sse-transport.test.ts | 23 | 0 (transport absent) | 11 | ~10: redirect/custom fetch variants (asserted `followRedirects == false`), hanging-POST abort with abort reason identity, OAuth refresh race through `auth()` (Swift uses `MCPOAuthProvider` hook), `deserializeMessage` (covered by secure-parse case) |
| tool/oauth.test.ts | 116 | ~60 | 3 | ~53 granular discovery/registration/auth-function cases; core behaviors already covered by MCPOAuth*Tests/Weekly*OAuth tests; not exhaustively re-mapped |
| tool/oauth-discovery-runtime.test.ts | 11 | ~7 | 0 | DNS/redirect runtime cases are platform-specific (native DNS pinning) |
| tool/oauth-credential-invalidation.test.ts | 7 | ~4 | 0 | shared-store refresh races partially covered by WeeklyMCPCore20261011 |
| util/oauth.util.test.ts | 9 | ~6 | 0 | resource URL helpers mostly covered |
| tool/mcp-events.test.ts | 21 | ~12 | 0 | |
| tool/mcp-event-webhook.test.ts | 33 | ~15 | 0 | Web `Request`/`Response` handler shape is platform-adapted |
| tool/mcp-events-adapter*.test.ts | 7 + 12 | ~8 | 0 | |
| tool/mcp-apps.test.ts | 10 | ~7 | 2 | `calls app-visible tools through the MCP client` (covered by client tests) |
| tool/mcp-app-fingerprint.test.ts | 4 | 0 (API absent) | 4 | |
| tool/json-rpc-message.test.ts | 4 | 0 (API absent) | 3 | schema non-export check is JS-only |
| tool/mcp-http-headers.test.ts | 4 | 4 | 0 | |
| tool/mcp-input-required.test.ts | 4 | 4 | 0 | (MCPMultiRoundTripTests, Weekly20261101MCPTests) |
| tool/types.test.ts | 8 | 7 | 0 | cyclic/BigInt structured content is JS-only |
| tool/mcp-stdio/*.test.ts | 3 + 6 + 11 | 3 | 0 | platform-only (Node child_process/env) |
| index.test.ts | 1 | - | - | JS export surface |

### Divergences

| # | Upstream evidence | Swift evidence (before) | Verdict | User-visible effect |
| --- | --- | --- | --- | --- |
| 1 | mcp-client.ts:1349-1381,1406-1428 (`metadata`, `title` on tool) | MCPClientActor.swift `tool(from:)` set only `providerMetadata["mcp"]` (with `_meta` mixed in) | fixed | MCP tool calls had no `title`/`toolMetadata`; MCP Apps `app` metadata missing. Now `AITool.title`/`metadata` match `McpProviderMetadata`; `_meta` stays in providerMetadata |
| 2 | mcp-client.ts:1413-1417 | only set `additionalProperties` when absent | fixed | server `additionalProperties: true` leaked into model tool schema |
| 3 | mcp-client.ts:1176-1188 (`arguments: args` undefined) | getPrompt default `.object([:])` | fixed | `prompts/get` always sent `"arguments":{}`; now omitted unless given (`arguments: JSONValue? = nil`, source-compatible) |
| 4 | mcp-client.ts:810-860, 692-697, 755 | different messages | fixed | `Server does not support tools`, `Attempted to send a request from a closed client`, `Server's protocol version is not supported: X`, `Unsupported method: X`; falsy capability treated as absent |
| 5 | mcp-client.ts:1738-1757 | handler `MCPClientError` -> -32602 "Invalid elicitation request" | fixed | handler failures now -32603 with the error message and reported via `onUncaughtError` |
| 6 | mcp-client.ts:1053-1071 + provider-utils retry-with-exponential-backoff.ts | immediate retries, raw last error, only `MCPClientError.statusCode` | fixed | 2s/4s/... backoff, `Failed after N attempts. Last error: ...` / non-retryable wrappers, `AIAPICallError` status and Foundation `URLError`/`POSIXError` network codes retried |
| 7 | mcp-client.ts:999-1003 (requestOnce rejects send errors directly), 908-919 (wrap only in modern loop) | `requestRounds` wrapped every non-MCPClientError | fixed | legacy transport/network errors were rewrapped as "Failed to process server response" (also prevented network retries) |
| 8 | mcp-client.ts:1387 (`const self = this`, strong) | `[weak self]` tool closures | fixed | tools from a dropped client failed with "MCP client has been released." |
| 9 | mcp-transport.ts:211-216 (`http` -> `initialProtocolVersion ?? LATEST_PROTOCOL_VERSION`) | MCPHTTPTransport default legacy | fixed | extra GET SSE (legacy protocol header) before `server/discover` against modern servers |
| 10 | mcp-transport.ts:146-152, http:77, sse:47 (`redirect='error'`) | URLSession default follows redirects | fixed | redirects silently followed; new `followRedirects: Bool = false` on HTTP/SSE transports |
| 11 | mcp-http-transport.ts:331-337, 357-369, 500-528, 601-611 | Swift messages/flow | fixed | `POSTing to endpoint (HTTP n): body` message; `GET SSE failed: 503 Service Unavailable`; inbound GET 404 expires session; 202 re-opens inbound SSE; reconnect delay x1.5 capped 30s |
| 12 | mcp-http-transport.ts:160-164, sse:86-90 | no user-agent | fixed | `user-agent: ai-sdk/2.0.99` suffix added (hard-coded baseline version) |
| 13 | mcp-sse-transport.ts (whole), mcp-transport.ts:209 | no SSE transport | fixed | new `MCPSSETransport` (endpoint event, same-origin check, POST, response routing, server requests, 401 recovery, `onError`) |
| 14 | mcp-apps.ts:124-134, 149-171 | `_meta.ui ?? _meta`; malformed fields kept | fixed | resource metadata now only `_meta.ui`; non-bool `prefersBorder`, non-object `permissions`/`csp` dropped; tool meta visibility normalized |
| 15 | mcp-app-fingerprint.ts | absent | fixed | `MCPApps.fingerprint(_:)`, `MCPApps.detectResourceDrift(current:baseline:)` |
| 16 | json-rpc-message.ts:66-68 (stable export) | absent | fixed | `MCPJSONRPC.validateMessage(_:)` (strict schemas) |
| 17 | mcp-client.ts:1330-1501 (`tools({schemas})`, `extractStructuredContent`) | absent | fixed | `tools(schemas:)` / `toolsFromDefinitions(_:schemas:)` + `MCPToolSchema`; typed non-dynamic tools; outputSchema validation with upstream messages; isError bypass |
| 18 | oauth.ts:1050-1072, 1150-1172, 822-836; URLSearchParams | resource set before client auth (visible to custom auth); `urlQueryAllowed` encoding; empty state/scope sent; `set` moved items | fixed | token form bytes now match URLSearchParams order/encoding; custom authenticators no longer see `resource` |
| R1 | mcp-client.ts:479 (`'ai-sdk-mcp-client'`) | `clientName = "swift-ai-sdk-mcp-client"` | reported | initialize `clientInfo.name` and tool `metadata.clientName` differ on the wire; undocumented; changing a public default (and generated docs) left to maintainers |
| R2 | mcp-http-transport.ts:198-218 / sse (auth() refreshes first) | MCPHTTPTransport.swift `MCPAuthorizationRecoveryCoordinator` calls `invalidateCredentials(.tokens)` then `authorize` | reported | on 401 Swift discards tokens before the app's authorize hook, so a refresh-token path cannot run; there is no built-in bridge from `MCPOAuthClientProvider` to the transport (upstream transports run `auth()` themselves). Needs API design; existing tests assert the invalidation |
| R3 | mcp-client.ts:533-537 (`{ type: 'sse', url }`) | `MCPEventTransportMetadata` has only `.http`/`.custom` | reported | SSE clients give managed event adapters `.custom`; adding an enum case is source-breaking |
| R4 | transports' `onerror` -> client `onUncaughtError` | MCPHTTPTransport has no error callback | reported | inbound SSE/parse errors on Streamable HTTP are not surfaced (SSE transport got `onError`) |
| R5 | mcp-apps.ts:149-160 (throws) | `toolsFromDefinitions` non-throwing | platform/API | invalid `ui://` URI omits `app` metadata instead of failing `tools()` |
| R6 | types.ts:604-611 (`requestedSchema: z.unknown()`) | MCPElicitationRequest requires requestedSchema | reported (minor) | elicitation without `requestedSchema` rejected with -32602 |
| R7 | types.ts ToolSchema (inputSchema required) | defaults to `{"type":"object"}` | reported (minor) | malformed tool lists accepted |
| R8 | requestOnce parse error "Failed to parse server response" | typed Swift parse messages | platform | error message text only |
| R9 | `tool({ outputSchema })` | core `AITool` has no outputSchema field | reported | typed MCP tools do not expose outputSchema to core |
| R10 | registerClient `JSON.stringify` | JSONEncoder (escaped `/`, unordered keys) | platform | semantically identical JSON |
| P1 | JSON.stringify insertion order | sorted keys in structured-content text and unknown-part text | platform | Swift dictionaries are unordered |

### Files changed
- Packages/swift-ai-mcp/Sources/SwiftAIMCP/MCPClientActor.swift
- Packages/swift-ai-mcp/Sources/SwiftAIMCP/MCPHTTPTransport.swift
- Packages/swift-ai-mcp/Sources/SwiftAIMCP/MCPSSETransport.swift (new)
- Packages/swift-ai-mcp/Sources/SwiftAIMCP/MCPApps.swift
- Packages/swift-ai-mcp/Sources/SwiftAIMCP/MCPOAuthFlow.swift, MCPOAuthToken.swift, MCPOAuthHelpers.swift
- Packages/swift-ai-mcp/Tests/SwiftAIMCPTests/MCPUpstreamParityNovember2026Tests.swift (new, 33 tests)
- Packages/swift-ai-mcp/Tests/SwiftAIMCPTests/MCPClientTests.swift, MCPHTTPTransportStreamingTests.swift (legacy transports now pass `initialProtocolVersion`, upstream POST message), MCPOAuthTestSupport.swift (`+` form decoding)
- Packages/swift-ai-mcp/Porting/map.json (new files + difference note)
- docs-site/scripts/component-guides/mcp.md (Transports/Tools sections; generated `components/mcp.mdx` not regenerated)

### Tests
`swift test --package-path Packages/swift-ai-mcp --no-parallel`: 186 tests passed (153 before this change + 33 new).

## xAI, Mistral, Groq and Cohere

## Parity audit — chat-providers (xai, mistral, groq, cohere)

Upstream: `@ai-sdk/cohere` 4.0.84, `@ai-sdk/groq` 4.0.84, `@ai-sdk/mistral` 4.0.87, `@ai-sdk/xai` 5.0.46
(paths below are relative to `scratchpad/upstream-all/pkg/<slug>/npm/src` unless marked `repo-src`).
Sub-agents could not be started (concurrency limit), so the whole group was audited by one agent. Depth was
prioritised on request bodies, prompt conversion, tool output mapping, stream sequencing and provider metadata.
The large secondary surfaces (xAI realtime/files/batch/transcription/speech, the xAI Responses *response
parser* which lives in `swift-ai-openai`, Mistral realtime/speech/transcription/streaming transcription) were
only spot-checked; no divergences are claimed for them either way.

Test-case counting: `it(`/`it.each(`/`test(` lines in upstream `*.test.ts` (each `.each` counted once).
"Already translated" is an estimate from mapping existing Swift tests by scenario; previous Swift tests are
mostly aggregate tests, so several upstream cases share one Swift test.

---

### @ai-sdk/cohere → Packages/swift-ai-cohere

Upstream test cases: 125 (7 files). Already translated (scenario-equivalent): ~40. Newly translated: 22
(`CohereUpstreamParityTests.swift`) + 2 existing tests rewritten to upstream expectations. Still missing: ~60 —
mostly snapshot-based content/usage/raw-chunk assertions already covered in aggregate form, citation schema unit
tests (`cohere-citations.test.ts`, Swift has no separate schema layer), `lazy-schemas.test.ts` (JS lazy zod
mechanics, platform-only), BigInt/circular serialisation cases (no BigInt/cycles in `JSONValue`, platform-only).

| # | Divergence | Upstream evidence | Swift evidence (after fix) | Verdict | User-visible effect |
|---|---|---|---|---|---|
| C1 | Non-image file parts other than `text/*`/`application/json` threw `invalidArgument`; upstream turns every non-image file into a document (media type not read) | `convert-to-cohere-chat-prompt.ts:96-131`; repo-src test `convert-to-cohere-chat-prompt.test.ts:92-159`, `cohere-chat-language-model.test.ts:583-616` | `CohereLanguageModel.swift:542` | fixed | PDFs / top-level `text` files were rejected instead of being sent as documents |
| C2 | Partial image media types: `image/*`/`image` were hard-coded to `image/jpeg`; upstream resolves the full type from bytes (`resolveFullMediaType`) and throws when undetectable | `convert-to-cohere-chat-prompt.ts:225-228`; test `:343-367` | `CohereLanguageModel.swift` `cohereContentPartJSON` | fixed | PNG data sent with a `top-level image` type was labelled JPEG |
| C3 | Image `detail` provider option (`providerOptions.cohere.detail` on the image part → `image_url.detail`) was ignored | `convert-to-cohere-chat-prompt.ts:73-90`, options `cohere-chat-language-model-options.ts:38-49`; test `:232-293` | `CohereLanguageModel.swift:528` | fixed | Image fidelity could not be set |
| C4 | `execution-denied` default text was `Tool execution denied.`; upstream `Tool call execution denied.` | `convert-to-cohere-chat-prompt.ts:186` | `CohereLanguageModel.swift:488` | fixed | Different tool message content |
| C5 | Plain string tool results were JSON-quoted (`"\"text\""`); upstream treats a string output as `text` | AI SDK tool-output model (`text` output) + `convert-to-cohere-chat-prompt.ts:180-192` | `cohereToolResultContent` | fixed | Extra quotes in tool messages |
| C6 | Tool messages without results (approval-only) produced a fake `{"role":"tool","content":""}` message | `convert-to-cohere-chat-prompt.ts:173-205` (filter + map only) | `cohereMessageJSON` `.tool` | fixed | Extra empty tool message sent to Cohere |
| C7 | Assistant text parts were joined with `\n` (`combinedText`); upstream concatenates without separator | `convert-to-cohere-chat-prompt.ts:144-149` | `CohereLanguageModel.swift:422` | fixed | Altered assistant history text |
| C8 | Warning order: reasoning warnings were emitted before tool/prompt warnings; upstream pushes tool + prompt warnings first, then thinking warnings | `cohere-chat-language-model.ts:122-160` | `CohereLanguageModel.swift:243` | fixed | Warning order |
| C9 | `tools` omitted when every tool was filtered (provider tools / unmatched forced tool); upstream sends `tools: []` (+ tool_choice) whenever tools were provided | `cohere-prepare-tools.ts:30-60` | `CohereLanguageModel.swift:234` | fixed | Request body shape |
| C10 | Generate tool-call input was re-encoded (sorted keys, `\/` escaping, empty→`{}`); upstream keeps the string verbatim except literal `null`→`{}` | `cohere-chat-language-model.ts:206-215` | `cohereGeneratedToolCalls` (`:595`) | fixed | Tool-call `arguments` text differed |
| C11 | Streamed tool-call arguments: invalid JSON / `__proto__` keys were passed through raw; upstream `parseJSON` fails the stream | `cohere-chat-language-model.ts:404-424`; test `:1886-1941` | `cohereStreamedToolArguments` (`:610`) | fixed | Prototype-polluting / invalid arguments accepted |
| C12 | Usage validation: non-numeric token counts were accepted; upstream schema rejects (generate throws; stream emits `error` + finish `error`, usage undefined) | `cohere-chat-language-model.ts:503-521`; tests `:1086-1113`, `:1360-1436` | `cohereUsageIsValid` (`:616`) | fixed | Invalid responses silently accepted |
| C13 | Unknown stream event types were ignored; upstream chunk schema is a discriminated union, so an unknown type is a validation error (error part, finish `error`) | `cohere-chat-language-model.ts:590-720` | `CohereLanguageModel.swift:183` | fixed | Finish reason / error parts |
| C14 | JSON stringification of tool results / rerank object documents escaped `/` (`JSONEncoder`), unlike `JSON.stringify` | `convert-to-cohere-chat-prompt.ts:192`, `reranking/cohere-reranking-model.ts` | `cohereJSONString` → `decisionJSONText` | fixed | `https:\/\/` in payloads |
| C15 | Tool `parameters` include tool metadata (`description`, and potentially `providerOptions`/`inputExamples`) because `request.tools` embeds metadata into the schema JSON; upstream sends `inputSchema` only | `cohere-prepare-tools.ts:49-57` | `cohereTools`; core `SwiftAI/CoreTools.swift:536-549`, `SwiftAI/ToolPreparation.swift:8-11,562` | **reported** (cross-package / core convention, same pattern in groq, mistral, xai, openai-compatible) | Extra keys inside `parameters` |
| C16 | Tool order: `request.tools` is a dictionary; Cohere sorts by name, upstream keeps declaration order | `cohere-prepare-tools.ts` | `cohereTools` | platform-only (core `LanguageModelRequest.tools` is `[String: JSONValue]`) | Tool order in body |
| C17 | Citation source ids are deterministic `cohere-citation-N`; upstream uses `generateId()` | `cohere-chat-language-model.ts:200` | `cohereSources` | platform-only (no `generateId` setting in Swift) | Source ids |
| C18 | Stream closes still-open text/reasoning blocks on a truncated stream; upstream emits no end part | `cohere-chat-language-model.ts:470-478` | stream tail | platform-tolerant extra end parts; not changed | Extra `text-end` on truncated streams |

Embedding (`cohere-embedding-model.ts`) and reranking (`reranking/cohere-reranking-model.ts`) request bodies,
precedence (`outputDimension` over `dimensions`), validation and warnings match. Provider factory/headers/URL
match; the umbrella (`Sources/SwiftAISDK/Providers/CohereCompatibility.swift`, `OpenAICompatibleProvider.swift:173,682,762`)
routes to the same package classes with user-agent `ai-sdk-cohere/4.0.84` — no divergence.

---

### @ai-sdk/groq → Packages/swift-ai-groq

Upstream test cases: 126 (8 files). Already translated: ~45. Newly translated: 9 (`GroqUpstreamParityTests.swift`)
+ 2 existing tests corrected. Still missing: ~70 — `groq-chat-language-model.test.ts` snapshot cases for raw
chunks/tool-call deltas (covered in aggregate by existing streaming tests), `convert-groq-usage.test.ts` unit
cases (behavior checked by reading: `groqUsage` matches), `groq-chat-language-model-options.test.ts` zod cases
(validated equivalently in `groqValidateChatProviderOptions`), `groq-lazy-schemas.test.ts` (platform-only),
BigInt/circular serialisation (platform-only).

| # | Divergence | Upstream evidence | Swift evidence | Verdict | Effect |
|---|---|---|---|---|---|
| G1 | Tool result content serialised the whole `modelOutput`/typed result wrapper (e.g. `{"type":"error-text","value":...}`); upstream maps text/error-text → value, execution-denied → reason or `Tool call execution denied.`, json/content → `JSON.stringify(value)`, string → text | `convert-to-groq-chat-messages.ts` tool branch | `GroqLanguageHelpers.swift:265` | fixed | Tool errors and typed outputs reached Groq as JSON wrappers |
| G2 | Assistant `reasoning` was taken only from `AIMessage.reasoning`; reasoning **parts** (what core multi-turn history uses) were dropped | `convert-to-groq-chat-messages.ts` assistant branch; test `:148-186` | `GroqLanguageHelpers.swift:202-205` | fixed | Multi-turn reasoning context lost |
| G3 | Partial image media types (`image`, `image/*`) → hard-coded JPEG / rejected; upstream `resolveFullMediaType` | `convert-to-groq-chat-messages.ts` file branch; tests `:229-313` | `GroqLanguageHelpers.swift:251` | fixed | Wrong data-URL media type / rejected `image` |
| G4 | `tools` omitted when all tools were unsupported (e.g. browser search on a non-GPT-OSS model); upstream sends `tools: []` and keeps `tool_choice` | `groq-prepare-tools.ts`; test `groq-prepare-tools.test.ts:310-333` | `GroqLanguageHelpers.swift:81` | fixed | Request body shape |
| G5 | Generate threw `No text content found` when `message.content` was null with no tool calls/reasoning; upstream returns empty content | `groq-chat-language-model.ts` doGenerate | `GroqModels.swift:46` | fixed | Spurious error |
| G6 | Streamed usage fell back to top-level `usage`; upstream reads only `x_groq.usage` | `groq-chat-language-model.ts` doStream (`value.x_groq?.usage`) | `GroqModels.swift:120` | fixed | Usage reported where upstream reports none |
| G7 | JSON stringification escaped `/` | — | `groqJSONString` → `decisionJSONText` | fixed | `\/` in tool content |
| G8 | Tool metadata inside `parameters` (same as C15) | `groq-prepare-tools.ts` | `groqTools` | reported (core convention) | — |
| G9 | Tool order follows dictionary iteration | — | `groqTools` | platform-only | — |

Catalog switches (browser search model list, `qwen/qwen3.6-27b` none-effort, GPT-OSS prefix, topK warning,
structuredOutputs/strictJsonSchema defaults, JSON response tool fallback) match `groq-model-catalog.ts`.
Transcription (URL mode, fragment stripping, redirect → nil, verbose response validation, segments/words) matches.
Umbrella `GroqCompatibility.swift` / `OpenAICompatibleProvider.swift:155,756` — no divergence.

---

### @ai-sdk/mistral → Packages/swift-ai-mistral

Upstream test cases: 225 (16 files). Already translated: ~70. Newly translated: 6 (`MistralChatUpstreamParityTests.swift`)
+ 1 existing test corrected. Still missing: ~150 — chat/conversation snapshot cases, realtime transport
(`realtime/*.test.ts`, 937 lines) and streaming transcription (`mistral-transcription-stream.test.ts`) suites,
speech/transcription request snapshots; these surfaces were not re-audited in depth this pass (time), see note at top.

| # | Divergence | Upstream evidence | Swift evidence | Verdict | Effect |
|---|---|---|---|---|---|
| M1 | Partial image media types hard-coded / rejected (`image`→error, `image/*`→JPEG) | `convert-to-mistral-chat-messages.ts:15-29, 80-110` | `MistralMessageParsing.swift:136` | fixed | Wrong data URLs |
| M2 | Non-image inline data only accepted exact `application/pdf`; upstream resolves the full media type (e.g. `application` + PDF bytes) and requires `application/pdf` | same, `:92-104` | `MistralMessageParsing.swift:139` | fixed | Valid PDFs rejected |
| M3 | Approval-only tool messages produced a fake tool message | `convert-to-mistral-chat-messages.ts:170-200` | `MistralMessageParsing.swift:37` | fixed | Extra message |
| M4 | String tool results JSON-quoted; `JSONEncoder` slash escaping | same | `MistralMessageParsing.swift:101,121` | fixed | Tool content text |
| M5 | Stream: within one chunk text was handled before thinking; upstream handles thinking first (reasoning-start/delta/end before text) | `mistral-chat-language-model.ts` doStream transform | `MistralModels.swift:86` | fixed | Stream part order |
| M6 | `tools`/`parallel_tool_calls` omitted when all tools were provider tools; upstream sends `tools: []` and `parallel_tool_calls` whenever tools were provided | `mistral-prepare-tools.ts`, `mistral-chat-language-model.ts` getArgs | `MistralModels.swift:170,191` | fixed | Request body |
| M7 | `usage: null` produced an all-nil usage object instead of none | `convert-mistral-usage.ts` | `mistralUsage` | fixed | Usage shape |
| M8 | Provider-reference PDF parts are resolved to `document_url`; upstream throws for every provider reference | `convert-to-mistral-chat-messages.ts:68-72` | `MistralMessageParsing.swift` `.providerReference` | **reported** (additive Swift capability; removing it would break callers; not documented as a divergence in `mistral.md`) | Swift accepts input upstream rejects |
| M9 | Tool metadata in `parameters` (C15) / dictionary tool order | — | `mistralTools` | reported / platform-only | — |

Conversation API request body (`store:false`, completion_args, unsupported-option warnings and order, reasoning
efforts) matches `mistral-conversation-language-model.ts` getArgs. Embedding body/precedence matches. Catalog
reasoning lists match `mistral-model-catalog.ts:138-260`. Umbrella `MistralCompatibility.swift` — no divergence.

---

### @ai-sdk/xai → Packages/swift-ai-xai

Upstream test cases: 416 (18 files). Already translated: ~110 (aggregate tests). Newly translated: 9
(`XAIResponsesInputUpstreamParityTests.swift`). Still missing: ~295 — the 5.5k-line
`xai-responses-language-model.test.ts` (21.8k-line snapshot; response/stream parsing is implemented in
`Packages/swift-ai-openai`, not editable here), `xai-batch.test.ts`, `xai-video-model.test.ts`,
`xai-transcription-model.test.ts`, `files/xai-files.test.ts`, realtime suites; `xai-provider.test-d.ts` and
`xai-video-options.test-d.ts` are type-only.

| # | Divergence | Upstream evidence | Swift evidence | Verdict | Effect |
|---|---|---|---|---|---|
| X1 | Assistant reasoning parts were always dropped with a warning; upstream replays them as `{type:"reasoning", id, summary:[summary_text], status:"completed", encrypted_content?}` when `providerOptions.xai.itemId` or `reasoningEncryptedContent` is present | `responses/convert-to-xai-responses-input.ts:150-190`; test `repo-src/responses/convert-to-xai-responses-input.test.ts:604-675` | `XAIResponses.swift:330-345` | fixed | Multi-turn reasoning (incl. `store:false` encrypted reasoning) was lost |
| X2 | Skip warning text differed (`...without xAI itemId...`) | same `:183-188` | `xaiReasoningReplayWarning` | fixed | Warning message |
| X3 | Assistant text `id` from `providerOptions.xai.itemId` not replayed | `convert-to-xai-responses-input.ts:113-124` | `XAIResponses.swift:300` | fixed | Item references lost |
| X4 | `content` tool outputs were flattened to a text string; upstream sends an array of `input_text`/`input_image` items | `convert-to-xai-responses-input.ts:240-285`; test `:424-476` | `xaiResponsesToolResultOutputValue` (`:428`) | fixed | Tool images dropped |
| X5 | Partial image media types hard-coded to JPEG; upstream `resolveFullMediaType` | `convert-to-xai-responses-input.ts:62-70`; tests `:676-770` | `XAIResponses.swift` user content | fixed | Wrong data-URL type |
| X6 | `imageDetail` file-part option (`providerOptions.xai.imageDetail` → `detail`) ignored | `convert-to-xai-responses-input.ts:66-78`, `xai-file-part-options.ts` | `xaiResponsesImagePart` (`:367`) | fixed | Image detail could not be set |
| X7 | Unsupported assistant part warnings used a generic message; upstream `xAI Responses API does not support <file|reasoning-file|custom> in assistant messages` | `convert-to-xai-responses-input.ts:191-203` | `XAIResponses.swift:321-327` | fixed | Warning text |
| X8 | JSON tool outputs escaped `/` | `JSON.stringify` | `xaiResponsesJSONString` (`:640`) | fixed | `\/` in outputs |
| X9 | Image provider metadata: empty `revised_prompt` and `cost_in_usd_ticks: null` were included; upstream includes only truthy/non-null | `xai-image-model.ts` doGenerate providerMetadata | `XAIModels.swift:1242,1248` | fixed | Metadata shape |
| X10 | Video provider metadata kept JSON `null` fields and, for upload delivery, dropped `progress`/`fileOutput`/`storageError` (upstream omits only `videoUrl`) | `xai-video-model.ts:776-820` | `XAIModels.swift:520,1255` | fixed | Missing/extra metadata |
| X11 | Non-image file parts with URL data (`input_file` + `file_url`) | `convert-to-xai-responses-input.ts:79-94` | — | platform-only (Swift `AIContentPart` has no non-image URL file case; `.imageURL` is image-only) | — |
| X12 | Tool order follows dictionary iteration (non-deterministic across runs) | `xai-responses-prepare-tools.ts` | `xaiResponsesTools` | platform-only (core) | Tool order |
| X13 | Function tool `parameters` include tool metadata (C15) | `xai-responses-prepare-tools.ts` | `xaiResponsesTools` | reported (core convention) | — |
| X14 | `XAIResponsesOptions.swift` (`xaiResponsesProviderOptions`, `xaiValidateResponsesProviderOptions` with a 4-value effort enum and include restricted to `file_search_call.results`) is dead code; the live validator is in `XAIResponses.swift` and matches upstream | — | `XAIResponsesOptions.swift` | reported (cleanup only, no behavior) | none |

Request body for `prepareRequest` (options, include/store handling, reasoning mapping, text format, tools and
tool_choice incl. server-side tool warning) matches `responses/xai-responses-language-model.ts:184-390` and
`xai-responses-prepare-tools.ts`. Umbrella `XAICompatibility.swift` + `OpenAICompatibility.swift:24`
(installs `configureXAIResponses`) — no divergence found.

---

### Files changed

- `Packages/swift-ai-cohere/Sources/SwiftAICohere/CohereLanguageModel.swift`
- `Packages/swift-ai-cohere/Tests/SwiftAICohereTests/CohereTests.swift` (2 tests corrected to upstream behavior)
- `Packages/swift-ai-cohere/Tests/SwiftAICohereTests/CohereUpstreamParityTests.swift` (new)
- `Packages/swift-ai-cohere/Porting/map.json` (registered new test)
- `Packages/swift-ai-groq/Sources/SwiftAIGroq/GroqLanguageHelpers.swift`, `GroqModels.swift`
- `Packages/swift-ai-groq/Tests/SwiftAIGroqTests/GroqProviderTests.swift`, `GroqStreamingAndTranscriptionTests.swift` (corrected)
- `Packages/swift-ai-groq/Tests/SwiftAIGroqTests/GroqUpstreamParityTests.swift` (new), `Porting/map.json`
- `Packages/swift-ai-mistral/Sources/SwiftAIMistral/MistralMessageParsing.swift`, `MistralModels.swift`
- `Packages/swift-ai-mistral/Tests/SwiftAIMistralTests/MistralLanguageAndEmbeddingTests.swift` (corrected)
- `Packages/swift-ai-mistral/Tests/SwiftAIMistralTests/MistralChatUpstreamParityTests.swift` (new), `Porting/map.json`
- `Packages/swift-ai-xai/Sources/SwiftAIXAI/XAIResponses.swift`, `XAIModels.swift`
- `Packages/swift-ai-xai/Tests/SwiftAIXAITests/XAIResponsesInputUpstreamParityTests.swift` (new), `Porting/map.json`
- `docs-site/scripts/provider-guides/cohere.md` (document handling paragraph)

### Test results (`swift test --package-path <pkg> --scratch-path .build/agent-chat-providers-<x> --no-parallel`)

- swift-ai-cohere: 51 tests passed
- swift-ai-groq: 44 tests passed
- swift-ai-mistral: 54 tests passed
- swift-ai-xai: 63 tests passed

`node Scripts/test-packages.mjs` and the umbrella compatibility suite were not run.

## OpenAI-compatible family

## Parity audit — group "compatible"

Upstream material: `scratchpad/upstream-all/pkg/<slug>/{npm,repo-src}` (npm baseline + matching-release tests).
Sections for deepseek, alibaba, huggingface/zai/gmicloud/vercel and baseten/cerebras/deepinfra/fireworks
were produced by per-package passes and are appended below unchanged; this first part covers
`@ai-sdk/openai-compatible`, `@ai-sdk/moonshotai`, `@ai-sdk/perplexity`, the cross-package follow-ups
that the wrapper passes requested of openai-compatible, and the final test run.

Disk note: the volume ran out of space during the run (`database or disk is full` while building
`swift-ai-tencent`). I removed only regenerable `.build` caches of packages in this group that were
already verified (`swift-ai-{deepseek,alibaba,perplexity,huggingface}/.build`). The root umbrella /
compatibility suite was NOT built or run (not enough disk for a full umbrella build); the root-test
impact below is from static reading.

### @ai-sdk/openai-compatible 3.0.92 -> Packages/swift-ai-openai-compatible

Upstream test cases (it/test counts): chat language model 141, convert-to-chat-messages 57, completion 30,
image 35, to-camel-case 17, provider 13, prepare-tools 12, embedding 9, chat-usage 3, content-array 2,
lazy-schemas 1 (total ~320). Before this pass the package had 16 Swift tests (most chat/message/image
behaviour is exercised only by root compatibility tests, which I could not run).

- Already translated (package): ~14 (warning/deprecation tests, prepareRequest/convertResponse,
  streaming tool-call struct tests).
- Newly translated: 24 tests in
  `Tests/SwiftAIOpenAICompatibleTests/OpenAICompatibleChatUpstreamParityTests.swift` (registered in
  `Porting/map.json`), covering: distinct ids for empty tool-call ids; partial and detailed usage;
  always-keyed provider metadata; created=0 placeholder; `openaiCompatible` / deprecated
  `openai-compatible` settings; provider-specific options pass-through (raw/camel/other-provider);
  camelCase metadata key; invalid typed options; tools + toolChoice body; responseFormat with/without
  structured outputs (+warning); reasoningEffort precedence/null/raw passthrough; textVerbosity vs raw
  verbosity; warning order; streaming tool deltas with late `function.name` (full sequence +
  finish usage/metadata); index starting at 1 (`anthropic-fallback-tool-call.sse` inline); id-less
  tool calls with reused index; error when a tool call never gets a name; response metadata after
  an empty placeholder chunk (`placeholder-first-chunk` inline); empty deltas / reasoning-after-text
  transitions; missing finish reason; includeUsage + stream body precedence; embedding typed options;
  completion unknown/content_filter finish reason + usage; completion text-delta stream snapshot.
- Still missing (reason): the large fixture snapshot tests (`xai-text`, `xai-tool-call`,
  `openai-compatible-refusal` full snapshots) — fixtures are not copied into the package and the
  generated Package.swift has no test resources; the convert-to-chat-messages matrix (57) and image
  matrix (35) — partially covered by root compatibility tests, not re-translated for time;
  to-camel-case (17), lazy-schemas, provider `.test-d.ts` — TS/zod-only; `config` getter tests —
  JS-only accessors.

#### Divergences (generic, non-OpenAI-backed endpoints; OpenAI/Azure/legacy wire profiles untouched)

| # | Upstream evidence | Swift evidence (before) | Verdict | User-visible effect |
|---|---|---|---|---|
| 1 | chat-language-model.ts:268-277 (`responseFormat` schema without structured outputs -> `unsupported` warning) | warning only emitted by zai's own adapter | fixed (`OpenAICompatibleChatModel.swift` preparedBody); zai duplicate removed (`ZAILanguageModel.swift`) | JSON schema silently downgraded to `json_object` without a warning (vercel, gmicloud, baseten..., generic) |
| 2 | chat-language-model.ts:262-354 (warning order: deprecations, topK, responseFormat, mapReasoning, tool warnings) | tool warnings preceded mapReasoning warnings | fixed | warning order |
| 3 | chat-language-model.ts:226-238, 335-349 (typed options from all namespaces; only raw/camel provider namespaces spread verbatim, typed keys excluded; reasoning_effort/verbosity/messages/tools written after the spread; zod validation) | every key from every namespace, incl. `openaiCompatible`, merged; camelCase keys renamed to snake_case (`parallelToolCalls`->`parallel_tool_calls`, `logprobs` rewritten, `serviceTier`...); no type validation; passthrough could override messages/tools/stream | fixed (`openAICompatibleUpstreamChatProviderOptions`, `OpenAICompatibleChatCommon.swift:313`) | wrong wire keys for provider options; non-typed `openaiCompatible` keys leaked into body; invalid `user`/`reasoningEffort`/... types sent instead of rejected |
| 4 | prepare-tools.ts:56-65 (`parameters: tool.inputSchema`, `strict` only when set) | `description`, `providerOptions`, `inputExamples` (Swift tool metadata) sent inside `parameters`; dictionary order | fixed (`openAICompatibleUpstreamChatTools`, sorted by name for determinism) | invalid/oversized JSON schema sent to servers |
| 5 | chat-language-model.ts:477 (`toolCall.id \|\| generateId()`) | `tool-call-<index>` fallback when id missing | fixed | duplicate/predictable ids across steps |
| 6 | chat-language-model.ts:491-505, 1001-1024 (`providerMetadata = {[key]: {}}` always) | `[:]` when nothing to report | fixed (generate + stream) | `providerMetadata[name]` missing |
| 7 | get-response-metadata.ts:16 (`created \|\| undefined`), chat-language-model.ts:745-757 (emit response-metadata once a chunk has id/model/non-zero created) | generic: created=0 -> 1970 timestamp; metadata emitted for the first chunk even if empty placeholder | fixed (chat generate/stream, completion) | wrong timestamp/id/model from placeholder chunks |
| 8 | convert-openai-compatible-chat-usage.ts:19-41 (counts default to 0, noCache = prompt - cached, no cacheWrite) | nil counts; cache-write subtracted; `usage: null` produced an all-nil usage | fixed (`openAICompatibleUpstreamChatUsage`; `totalTokens` keeps reported `total_tokens` – native field) | nil vs 0 usage values |
| 9 | chat-language-model.ts:600-656, 960-975 (tool-call deltas buffered by index until `function.name`; shared `StreamingToolCallTracker`; missing id generated; never-named call fails with "Expected 'function.name' to be a string.") | first delta without `id` threw "Expected 'id' to be a string."; first delta without name threw immediately | fixed (dedicated `upstreamCompatibleStream`, core `AIStreamingToolCallTracker`) | streams from Anthropic/Gemini-style gateways failed |
| 10 | chat-language-model.ts:780-830, 987 (empty reasoning/text deltas ignored; reasoning delta closes active text) | `content: ""` opened an empty text part; `reasoning_content` after text did not close text | fixed | spurious empty text parts, overlapping text/reasoning blocks |
| 11 | message `audio` not part of upstream generic schema | audio transcript used as text fallback | fixed (generic only) | invented text |
| 12 | embedding-model.ts:118-172 (only `dimensions`/`user`, namespaces `openai-compatible` < `openaiCompatible` < raw name; `encoding_format: "float"` always) | all namespace keys forwarded; `encoding_format` only for `.embedding` surface ids | fixed (`OpenAICompatibleMediaModels.swift:50`) | extra body keys (reported by the baseten pass) |
| 13 | completion-language-model.ts:240-250, 330-380, convert-...-completion-usage.ts | raw finish reason (`content_filter`, `eos`) returned unmapped in generate; stream response-metadata emitted before the first chunk without id; text part opened only when text present, id `txt-0`; usage nil vs 0; `logprobs: null` produced `{logprobs: null}` metadata | fixed (generic only) | unmapped finish reasons, missing response id, metadata noise |
| 14 | image-model.ts edit path uses the same error structure | edit failures used raw `apiCallError` | fixed (generic only) | error message is the raw body instead of the provider message |
| 15 | chat-language-model.ts (no logprobs in metadata) | `logprobs` added to `providerMetadata[name]` | reported, kept | additive; asserted by root `OpenAICompatibleTests.swift:656-722` |
| 16 | chat stream keeps only the last non-null `usage` for prediction tokens | prediction tokens merged across chunks | reported, kept | only differs when a later usage chunk drops a field; asserted by root `OpenAICompatibleTests.swift:676-705` |
| 17 | response_format sends `responseFormat.schema` as-is | `addAdditionalPropertiesToJSONSchema` adds `additionalProperties:false` when strict | reported, not fixed | schemas without explicit `additionalProperties` differ on the wire; shared by cerebras/togetherai and the umbrella; needs a coordinated decision |
| 18 | prepare-tools.ts:85-91 (unknown toolChoice type throws `UnsupportedFunctionalityError`) | unknown types produce an `unsupported` warning | reported | Swift `toolChoice` is free-form JSON, so the throw would be a source-behaviour break |
| 19 | completion getArgs spreads raw provider options verbatim (so `logitBias` is sent both raw and as `logit_bias`) | Swift renames | reported, not fixed (cosmetic, root test asserts renamed key) | |
| 20 | chat/embedding zod validation of response bodies | lenient parsing | platform/native leniency, reported | |

Root umbrella impact (read-only; not run): the umbrella `AIProviders.openAICompatible(name:...)` uses this
package with `usesGenericOpenAICompatibleProviderOptions = true`, so it now follows upstream. Known root test
that asserts the old divergent behaviour and must be updated by the root owner:
`Tests/SwiftAISDKTests/OpenAICompatibleResponseMetadataTests.swift:33-45`
(`genericOpenAICompatibleGeneratePreservesNonNullZeroTimestamp` expects `Date(timeIntervalSince1970: 0)`;
upstream `get-response-metadata.ts:16` drops `created: 0`). I statically checked OpenAICompatibleTests,
EmptyToolCallIDUpstreamParityTests, ProviderGroupBUpstreamParity20260831Tests, WeeklyLanguage20261025Tests,
WeeklyMajorProviders20261011Tests, OpenAIChatTests (generic cases) and kept native behaviours they assert
(logprobs metadata, cumulative prediction tokens, reported `total_tokens`, extraBody escape hatch and its
renaming). Other root tests may still be affected; please run
`node Scripts/sdk.mjs dev test --filter OpenAICompatible --no-parallel` when disk allows.

Umbrella `Sources/SwiftAISDK/Providers/OpenAICompatibleProvider.swift` (read-only findings):
- The umbrella builds `ModelHTTPConfig` with `usesGenericOpenAICompatibleProviderOptions = usesOpenAICompatibleSurfaceIDs`
  (false for baseten/deepinfra/fireworks/moonshotai/... registry entries) and `allowsEmptyTextResponse = false`,
  so umbrella wrappers keep the legacy path (no portable `reasoning`, empty-text responses throw); matches
  the baseten-group pass's report.
- `AIProviders.moonshotAI` still routes through `OpenAICompatibleChatModel` + `configureMoonshotChat`, not the
  new native `MoonshotAIChatLanguageModel`, so umbrella users do not get the moonshot fixes below.

Downstream changes made because of the shared fix:
- `Packages/swift-ai-fireworks/Sources/SwiftAIFireworks/OpenAICompatibleChatFireworks.swift`: Fireworks'
  transform now renames `promptCacheKey`/`serviceTier` itself (upstream fireworks-provider.ts:167-203),
  since the base no longer renames provider options.
- `Packages/swift-ai-zai/Sources/SwiftAIZAI/ZAILanguageModel.swift`: removed zai's duplicate
  responseFormat warning (the base now emits it in upstream order).

### @ai-sdk/moonshotai -> Packages/swift-ai-moonshotai

This package was ported by a pass that ran out of budget before writing its report; state below is from
the on-disk diff. Upstream tests: chat-language-model 84, convert-messages 39, normalize-json-schema 27,
usage 11, provider 5, prepare-tools 2, lazy-schemas 1 (169). Swift tests now 116 (was 38), including
78 in the new `MoonshotAIChatLanguageModelUpstreamTests.swift` (registered in map.json).

Fixed (from diff and provider guide): Moonshot now has a dedicated `MoonshotAIChatLanguageModel`
(`Sources/SwiftAIMoonshotAI/MoonshotAIChatLanguageModel.swift`, upstream moonshotai-chat-language-model.ts)
instead of the generic chat model with `usesGeneric=false` / `allowsEmptyTextResponse=false`:
`max_completion_tokens`; Kimi fixed-sampling warnings (temperature/topP/penalties omitted, topK/seed
warn); K2.6/K2.7 `toolChoice: required` omitted with a warning; media allow-lists and `ms://` pass-through;
message-level `name`/`partial`/dynamic `tools`; `strictJsonSchema`, `logprobs`/`topLogprobs`,
`prediction` options; provider options errors as `invalid moonshotai provider options`;
always-present `providerMetadata.moonshotai` with `responseObject`, `choiceIndex`, `messageRole`,
`toolCallTypes`, `logprobs`, `cacheWriteTokens` (msh-usage headers); stream: generated ids for id-less
tool calls (was "Expected 'id' to be a string."), interrupted finish when no finish reason, typed
provider stream errors, top-level vs choice usage precedence.
Reported: umbrella `AIProviders.moonshotAI` still uses the legacy path (see above).
Tests: 116 passed.

### @ai-sdk/perplexity -> Packages/swift-ai-perplexity

Upstream tests: language-model 42, decision-model 21, embedding 10, convert-input 6, decision-state 6,
usage 1, lazy-schemas 1 (87). Swift tests now 69, including 44 in new `PerplexityAgentUpstreamTests.swift`
(registered).

Fixed (diff): HTTP errors for Agent/Sonar/Embeddings/Decisions use upstream `perplexityErrorToMessage`
(`error`, `error.message`, `detail`, `message`) via `PerplexityModelConfiguration.httpStatusError`
(`PerplexityProvider.swift:104-133`); HTTP-200 `status: "failed"` responses throw with the response's
`error.message`; raw chunks are emitted before validation (upstream order); pending sources and
`text-end` are flushed in insertion order instead of dictionary order; empty text deltas are not
dropped; `numSearchQueries`/`toolCalls` metadata is `0`/`{}` (not null) when `tool_calls_details` is an
empty object. Umbrella `PerplexityCompatibility.swift` just wraps the package models.
Tests: 69 passed.

### Test results (final run, `swift test --package-path Packages/<pkg> --no-parallel`)

See the table at the end of this file.

---

### @ai-sdk/deepseek 3.0.87 → Packages/swift-ai-deepseek

Upstream: `pkg/deepseek/npm/src` (= `repo-src`, byte-identical). Paths below are relative to that `src/`.
Swift paths are relative to `Packages/swift-ai-deepseek/Sources/SwiftAIDeepSeek/`.

#### Upstream test cases (counting each `it`/`it.each` once)

| file | cases | before this pass | newly translated | still missing |
|---|---|---|---|---|
| chat/deepseek-chat-language-model.test.ts | 66 | ~28 equivalent (options, names, prefix, strict, images, errors, logprobs stream, reasoning mapping) | 14 (V4 sampling omission/warnings ×2, logprobs ×2 + false omission, provider effort it.each, adaptive text, tool-call extraction, fingerprint null/undefined, stream tool-call types, JSON-schema warning order) | ~24 fixture snapshot tests (`deepseek-text/reasoning/tool-call/json` `.json`/`.chunks.txt` full-result snapshots). Their observable outcomes are partially covered by narrower assertions; full snapshots not translated (fixtures not copied; JS result shape differs). |
| chat/convert-to-deepseek-chat-messages.test.ts | 36 | ~24 (via request bodies) | 0 | ~12 pure converter edge cases (bigint/cycle stringify, `tool-approval-response` skip, role-default warning). Not reachable or JS-specific. |
| chat/deepseek-raw-usage.test.ts | 3 (one it.each×3) | 0 | 3 (generate raw usage, stream final usage, invalid known usage fields) | 0 |
| chat/convert-to-deepseek-usage.test.ts | 3 | 2 | 0 | 0 effectively (clamp covered by usage math) |
| chat/deepseek-prepare-tools.test.ts | 7 | 6 (Weekly20261108ToolTests, strict tests) | 0 | 1 (ordering of multiple tools: Swift `request.tools` is a dictionary — core limitation) |
| chat/is-deepseek-v4-model.test.ts | 2 it.each | covered by V4 reasoning_content tests | 0 | 0 |
| chat/deepseek-internal-options / lazy-schemas (.test.ts) | 6 | n/a | 0 | 6 — zod composability/lazy init; platform-only |
| *.test-d.ts (7 files) | type tests | n/a | 0 | platform-only (TS types) |
| files/deepseek-files.test.ts | 20 | ~16 | 0 (assertion updated to the en-US grouped message) | ~4 Blob/FormData-specific |
| responses/convert-to-deepseek-responses-input.test.ts | 48 | ~20 | 1 (`fileData: false` rejected) | ~27 per-type it.each rows; most behaviours exercised by grouped Swift tests, not row-by-row |
| responses/deepseek-responses-language-model.test.ts | 14 | ~10 | 1 (warning order) | ~3 fixture snapshot tests (`deepseek-responses*.json/.chunks.txt`) |

Totals: ~215 upstream cases incl. type/lazy tests; ~106 previously equivalent; 20 new Swift test functions (78 Swift tests total, all passing).

#### Divergences

1. **Portable `reasoning` ignored when the endpoint cannot take `thinking` (Azure-hosted DeepSeek).** Upstream computes `reasoning_effort` independently of `capabilities.reasoning.configurable` (chat/deepseek-chat-language-model.ts:351-363, 402-405); azure test `should map top-level reasoning to Azure DeepSeek reasoning effort` expects `reasoning_effort: "high"`. Swift only applied portable reasoning when `supportsThinking` (old DeepSeekRequestPreparation.swift:79). Effect: `azure.deepseek(...)` with `reasoning: "high"` sent no effort. **Fixed** (DeepSeekRequestPreparation.swift:149-171).
2. **Provider options namespace hard-coded to `deepseek`.** Upstream parses `providerOptions[providerOptionsName]` (`azure` for `azure.deepseek`) (chat model :226-251). Swift read only `deepseek` (DeepSeekOptions.swift:12). Effect: `providerOptions.azure.reasoningEffort` ignored on Azure DeepSeek. **Fixed** (DeepSeekOptions.swift:14) — reads the provider namespace when present, keeps `deepseek` as fallback (documented compat; the Azure package's existing test relies on it).
3. **Provider metadata key hard-coded to `deepseek` and omitted when empty.** Upstream always returns `{[providerOptionsName]: {...}}` (chat model :482-503, :728-755). Swift returned `["deepseek": …]` or `[:]` (DeepSeekToolsAndParsing.swift old :187-207). **Fixed** (DeepSeekToolsAndParsing.swift:208-230); `toolCallTypes` also drops null types like upstream `.filter`.
4. **Streaming provider metadata.** Upstream collects `toolCallTypes` from delta tool calls ordered by index, latest non-null scalars, and concatenated `content`/`reasoning_content` logprobs (chat model :556-561, :704-752). Swift merged per-chunk metadata: no streamed `toolCallTypes`, a later `logprobs: {content: null}` chunk could drop accumulated logprobs. **Fixed** with `DeepSeekStreamMetadata` (DeepSeekToolsAndParsing.swift:236-285).
5. **Stream usage reset.** Swift `deepSeekUsage(from:)` returned an empty `TokenUsage()` for chunks without usage, overwriting the real usage if any chunk followed it (DeepSeekModels.swift old :198); upstream only updates on non-null `usage` (:609-611). `usage: null` in generate also produced zero counts instead of null usage. **Fixed** (DeepSeekModels.swift:206-208, DeepSeekToolsAndParsing.swift deepSeekUsage guard).
6. **Generate content order / null content.** Upstream content is reasoning → tool calls → text, and a null/empty `content` simply yields no text part (:446-473). Swift synthesized reasoning → text → tool calls and threw `No text content found` when content was null without tool calls (DeepSeekModels.swift old :121). **Fixed** (DeepSeekModels.swift:129-135).
7. **`logprobs: false` sent.** Upstream sends `logprobs: true` only when `logprobs === true` or `topLogprobs` set (:368-372). Swift forwarded `logprobs: false`. **Fixed** (DeepSeekRequestPreparation.swift:55).
8. **`thinking: {}` sent.** Upstream sets `thinking` only when `thinking.type` is present, otherwise falls back to portable reasoning (:320-326). Swift sent `"thinking": {}` and blocked portable reasoning. **Fixed** (DeepSeekRequestPreparation.swift:67).
9. **Warning content and order.** Upstream: deprecated penalties use `setting` + "… Remove X from the request."; temperature/topP `details` "… Set providerOptions.deepseek.thinking.type to 'disabled' to use …"; effort/adaptive texts `reasoningEffort "medium" is not a canonical DeepSeek value. mapped to "high".`; order = message warnings (JSON-schema injection first, convert-to-deepseek-chat-messages.ts:111-115) → topK → seed → penalties → adaptive → temperature → topP → effort → tool warnings (:269-407). Swift used `feature` for deprecations, shortened texts, emitted the schema warning after topK/seed and sampling warnings after tool warnings. **Fixed** (DeepSeekRequestPreparation.swift:103-171 and message conversion); existing Swift tests updated to the upstream texts.
10. **Usage validation.** Upstream's loose usage schema rejects non-numeric known fields (chat/deepseek-chat-api-types.ts:98-117; raw-usage test `continues validating known usage field`). Swift silently coerced to 0. **Fixed**: generate throws `invalidResponse`, stream emits an error part and finishes with `error` (DeepSeekModels.swift:122, :201).
11. **Responses warning order.** Upstream maps portable reasoning after tool preparation (responses/deepseek-responses-language-model.ts:146-178). Swift emitted reasoning warnings before tool warnings. **Fixed** (DeepSeekResponsesRequest.swift:75).
12. **Responses `fileData: false` accepted.** Upstream schema `fileData: z.literal(true)` (chat/deepseek-file-part-options.ts:26) rejects false; Swift accepted it in Responses image parts. **Fixed** (DeepSeekResponsesRequest.swift:149).
13. **Files size error text.** Upstream formats with `toLocaleString('en-US')` ("67,108,864 bytes") (files/deepseek-files.ts:160-167). Swift printed raw integers. **Fixed** (DeepSeekFiles.swift:114).

Platform-only / relied upon (not changed):
- No raw finish reason on `TextGenerationResult` (core type); `stop: []` vs omitted not distinguishable (`stopSequences` is non-optional); tool order follows Swift dictionary order (core `request.tools: [String: JSONValue]`); no zod schema validation of the full response; `totalTokens` computed in Swift usage.
- Web-search tool results carry `providerExecuted: true` (Swift tool-result model) where upstream omits the flag.
- `DeepSeekProviderSettings.supportsStructuredOutputs`/`queryParams` and the `extraBody` escape hatch are Swift extensions (no upstream equivalent; documented as native settings).

Reported, not fixed (outside this package):
- **Umbrella `AIProviders.deepSeek(settings:)` (`Sources/SwiftAISDK/Providers/OpenAICompatibleProvider.swift:264-282`)**: `responses(_:)`/`responsesModel(_:)` returns the generic `OpenAICompatibleResponsesModel`, not `DeepSeekResponsesLanguageModel`. Upstream `deepseek.responses()` uses the DeepSeek Responses model (web_search tool, effort mapping `minimal→low, medium→high, xhigh→max`, `thinking.disabled→none`, `providerMetadata.deepseek.{responseId,serverToolUse,logprobs}`, reasoning `itemId`). The umbrella route therefore diverges for every Responses call. `DeepSeekCompatibility.swift` itself only bridges config and is fine; umbrella chat/files route to the package models and pick up the fixes above.
- The umbrella passes `settings.supportsStructuredOutputs` into native DeepSeek; upstream native DeepSeek never enables json_schema (only Azure does). Opt-in only, default false — low risk.

#### Files changed
- Sources: DeepSeekRequestPreparation.swift, DeepSeekOptions.swift, DeepSeekModels.swift, DeepSeekToolsAndParsing.swift, DeepSeekResponsesRequest.swift, DeepSeekFiles.swift
- Tests: new DeepSeekChatUpstreamParityTests.swift (3 suites, 20 tests); DeepSeekProviderTests.swift and DeepSeekVisionAndFilesUpstreamParityTests.swift assertions updated to upstream warning/error texts
- Porting/map.json: registered the new test file
- docs-site provider guide: no change needed (it does not describe the fixed behaviours)

#### Test results
- `swift test --package-path Packages/swift-ai-deepseek --no-parallel`: 78 tests in 8 suites passed.
- Consumer check: `swift test --package-path Packages/swift-ai-azure --no-parallel --filter azureDeepSeek`: 1 test passed (Azure-hosted adapter still honours its existing `providerOptions.deepseek` test via the fallback).

---

## @ai-sdk/alibaba 2.0.91 → Packages/swift-ai-alibaba

Upstream: `upstream-all/pkg/alibaba/npm/src` (dist checked for the touched strings, identical) and
`repo-src/*.test.ts` (UP below). Swift: `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/*` (SW below).

### Upstream test cases

180 cases (`it`/`it.each` counted once) in 11 files. Counts per file are approximate where one Swift test covers several cases.

| File | Total | Already translated | Newly translated | Still missing (reason) |
|---|---|---|---|---|
| alibaba-chat-language-model.test.ts | 28 | 6 (body shape, cache-token usage, enable_thinking, provider options, missing usage, stream reasoning+usage) | 19 (text body/metadata, 3 response-format, tool-call extract, reasoning usage, raw cache_type, reasoning-only follow-up, 4 top-level reasoning, preserveThinking default/opt-out/explicit/same-round, 3 stream endings, stream tool-call fixture, empty tool_calls keeps reasoning) | 3 partial: `should stream text`/`should stream reasoning`/`should extract text/reasoning content` snapshots use 274–401-line fixtures; asserted with the fixture's first/last chunks inline rather than the full snapshot (Package.swift is generated, so no test resources). Stream `preserveThinking:false` uses the same conversion as the generate test. |
| convert-to-alibaba-chat-messages.test.ts | 33 | 3 (prior-round reasoning omission, reasoning-only omission) | 24 (array formats, assistant tool calls, tool results, all 12 cache-control cases, 2 preserved cache cases, provider reference throws, 4 media-type resolution) | ~6 preserveThinking variants not duplicated: covered by the chat-level tests through the same function |
| get-cache-control.test.ts | 3 | 0 | 3 | – |
| alibaba-prepare-tools.test.ts | 13 | 0 | 13 (in 4 Swift tests) | – |
| alibaba-provider.test.ts | 20 | 4 (default URL, headers/user-agent, credentials, chat alias) | 6 (default/custom embedding and video base URLs, includeUsage) | 10 platform-only: checks on mock constructors, custom `fetch` identity, the headers function, and `new` |
| alibaba-video-model.test.ts | 62 | ~40 (13 existing Swift tests for legacy/wan2.7/wan3 mapping, frames, references, errors, metadata) | 9 (wan3 tier warning, warning order, wan2.7 audio warning, per-reference warnings and the video-URL regex, FAILED message, missing task_id, completed providerMetadata, media override field mapping) | ~13: pending/RUNNING `doStatus` results and `_internal.currentDate` timestamps (platform-only: the Swift model polls internally and does not expose doStart/doStatus); task-ID path encoding is a core `encodePathSegment` concern |
| convert-alibaba-usage.test.ts | 5 | 2 (clamping, raw) | 3 (distribution, null usage, raw cache_type) | – |
| embedding-model.test.ts | 11 | 6 (endpoint/body, provider options, sparse metadata, sparse-only reject, too many values, headers) | 3 (dimension precedence it.each, text_index order, usage present/absent) | 2 (raw response body/headers): already exposed via responseMetadata, not re-asserted |
| lazy-schemas.test.ts | 1 | – | – | platform-only (zod lazy schema) |
| supports-json-schema-output / supports-preserved-thinking | 4 | – | covered behaviorally (qwen3.8-flash vs deepseek-v4.1-flash, qwen3.7-max default) | The lists were compared by reading: identical to `alibaba-model-catalog.ts:197-233` |

### Divergences

| # | Upstream evidence | Swift evidence (before) | Verdict | User-visible effect |
|---|---|---|---|---|
| 1 | UP `convert-to-alibaba-chat-messages.ts:49-243`, `get-cache-control.ts:1-49`: `providerOptions.alibaba.cacheControl` becomes `cache_control` on text/image/tool blocks (part beats message; message-level marker on the last part); more than 4 markers produce an `other` warning | SW `AlibabaRequestPreparation.swift` `alibabaMessageJSONs`: no cache control at all | **fixed** | Explicit context caching (and its pricing) was impossible: markers were silently dropped |
| 2 | UP `alibaba-chat-language-model.ts:256-260`: null `content` gives an empty content list (reasoning-only responses are valid) | SW `AlibabaModels.swift:38-40` threw `invalidResponse("No text content found…")` | **fixed** | Reasoning-only or empty responses (e.g. `finish_reason: length` during thinking) failed the call |
| 3 | UP `convert-to-alibaba-chat-messages.ts:94-124`: non-image files, text files and provider references throw UnsupportedFunctionalityError; `image`/`image/*` resolve the subtype from the bytes | SW `alibabaUserContentParts`: warned and dropped the part; checked only the `image/` prefix | **fixed** (now throws `AIError.invalidArgument` with the upstream message; detects the subtype with `resolveFullMediaType`) | PDFs and other files were silently removed from the prompt; a bare `image` type was rejected |
| 4 | UP `alibaba-prepare-tools.ts:40-47`: `parameters = tool.inputSchema` | SW `AlibabaTools.swift:18-31` left `description`, `providerOptions` and `inputExamples` (Swift tool metadata) inside `parameters`; tools came from unordered dictionary iteration | **fixed** (metadata stripped; sorted by name) | The wire JSON schema carried non-schema keys; tool order was random per process |
| 5 | UP `alibaba-prepare-tools.ts:52-77`: unknown tool choice throws; when every tool is provider-defined, sends `tools: []` and tool_choice | SW: emitted an `unsupported` warning and omitted tools | **fixed** | The error contract differed; the request body differed |
| 6 | UP `alibaba-chat-language-model.ts:331-473` uses `StreamingToolCallTracker` (index/ID correlation, unique IDs, blank names, flush ordered by index) | SW used the simple `OpenAIStyleStreamingToolCalls` plus a local workaround, and emitted legacy `.toolCallDelta` parts | **fixed** (core `AIStreamingToolCallTracker`) | Wrong merging or duplicate IDs for parallel calls, reused IDs or indexes, and extra legacy parts |
| 7 | UP `:395` `activeReasoningId = generateId()` per reasoning block | SW: fixed `"reasoning-0"` | **fixed** | A second reasoning block reused the same ID |
| 8 | UP `convert-alibaba-usage.ts:40-43`: missing usage gives null usage (all undefined); `usage: null` chunks are ignored | SW: `TokenUsage(inputTokensNoCache: 0, inputTokensCacheWrite: 0)`; a JSON `null` usage overwrote the stream usage with zeros | **fixed** (`TokenUsage()`; null ignored) | Spurious 0 token counts |
| 9 | UP `alibaba-provider.ts:118-128,139-171`: `videoBaseURL` and `embeddingBaseURL` settings with intl defaults independent of `baseURL`; `includeUsage` setting | SW: no settings; embedding and video URLs derived from `baseURL` | **fixed** (added settings at the end of the settings init; the native provider uses upstream defaults; `AlibabaModelConfiguration` keeps deriving when the new fields are nil, for the umbrella) | No way to target another region or a proxy separately; `stream_options` could not be disabled |
| 10 | UP `:133-135`: assistant text concatenated with no separator | SW `combinedText` joined with `"\n"` | **fixed** | Multi-part assistant text was altered |
| 11 | UP `alibaba-video-model.ts:291-516`: warning content and order (resolveMedia/references → last_frame → inputReferences → resolution → shotType → generateAudio → aspectRatio → fps → n); one warning per skipped reference; tier list in order `480P, 720P, 1080P`; wan2.7 warns for the provider `audio` option too | SW `AlibabaVideoModels.swift` `alibabaVideoWarnings`: different order and messages, one aggregated warning, tiers listed as `1080P, 480P, 720P`, provider audio not warned | **fixed** | Warning text, order and count differed |
| 12 | UP `:183-185` `/\.(mp4|mov)([?#]|$)/i` | SW `contains(".mp4")` | **fixed** | Image URLs whose host contains `.mp4` were sent as `reference_video` |
| 13 | UP `:196-202`: media items mapped to `{type,url,reference_voice?}` | SW passed all keys through and sent `reference_voice: null` | **fixed** | Extra or null keys were sent |
| 14 | UP `:538-543,625-631,676-681`: messages `No video URL in response. Task ID: …`, `No task_id returned from Alibaba API. Response: …`, `Video generation failed. Task ID: X. <msg>`; actualPrompt only when non-empty | SW used generic messages | **fixed** | Error text differed |
| 15 | UP `alibaba-embedding-model-options.ts:27` `dimension: z.number()` | SW required a positive value | **fixed** | 0 or negative values threw locally instead of reaching the API |
| 16 | UP `parse-json-event-stream.ts`: `[DONE]` is ignored (reading continues); an unparsable chunk still yields a `raw` part when includeRawChunks | SW stopped at `[DONE]`; no raw part for invalid JSON | **fixed** (`.raw(.null)`) | Minor stream differences |
| 17 | UP `getArgs` warning order: frequencyPenalty, JSON-schema compatibility, reasoning, cache breakpoints, tools | SW: messages, tools, response format, thinking | **fixed** | Warning order |
| 18 | UP `alibaba-provider.ts:131-140` loads only `ALIBABA_API_KEY` | SW `AlibabaProvider.swift:38` (and umbrella `ProviderRegistry.swift:281`) also read `DASHSCOPE_API_KEY` | **reported**, not documented, not platform-required | An extra environment fallback; removing it could break existing users |
| 19 | UP finish `raw` reason (`{unified, raw}`) | Core `LanguageStreamPart.finishMetadata` and `TextGenerationResult` have no raw finish-reason field | **platform/core gap** (reported) | `raw: "unknown_reason"` is not observable |
| 20 | UP JSON.stringify keeps insertion order | SW tool-result JSON now uses sorted keys and does not escape `/` | **platform-only** | Key order in `tool` message content |

Swift-only extensions kept as they were: extraBody passthrough and snake/camel aliases; numeric `reasoning` budget strings; warnings for Swift-only user parts (reasoning or tool parts inside user messages); `AIMessage.reasoning` is now replayed before reasoning content parts; video `seed`/`resolution`/`image` extraBody fallbacks; in-model polling (`pollIntervalMs`/`pollTimeoutMs`).

### Umbrella (`Sources/SwiftAISDK/**`, read-only)

- `ProviderRegistry.swift:280-281`: `AIProviders.alibaba(settings:)` wraps `OpenAICompatibleProvider` and builds `AlibabaModelConfiguration(http:baseURL:transformRequestBody:)` (`AlibabaCompatibility.swift:9,15,21`). It cannot pass `videoBaseURL`, `embeddingBaseURL` or `includeUsage`, so umbrella users keep the old behavior: video and embedding URLs derived from a custom `baseURL`, and usage always requested. With the default `baseURL` the result equals upstream. **Reported**: fixing it needs umbrella settings plumbing.
- The umbrella also accepts `DASHSCOPE_API_KEY` (item 18). The user agent `ai-sdk-alibaba/2.0.91` matches (`OpenAICompatibleProvider.swift:796`).
- The umbrella has no own JSON-schema or preserved-thinking list for Alibaba (it delegates to the package), so there is no list bug like the Together AI one.

### Cross-package observations (not fixed: outside this package)

- `swift-ai-openai-compatible` `openAICompatibleChatTools` (`OpenAICompatibleChatCommon.swift:39-63`) has the same leak as item 4: `description`, `providerOptions` and `inputExamples` stay inside `parameters`.
- Core `AIStreamingToolCallTracker` (the faithful port of upstream `StreamingToolCallTracker`) had no users. Other providers still use `OpenAIStyleStreamingToolCalls`, which lacks upstream correlation and ID de-duplication.

### Files changed

- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaProvider.swift`: new settings `videoBaseURL`, `embeddingBaseURL`, `includeUsage` (additive) and matching configuration fields.
- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaRequestPreparation.swift`: cache-control validator, message conversion, file errors, warning order, `tools: []`.
- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaTools.swift`: tool parameters, ordering, tool-choice errors.
- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaModels.swift`: generate without a throw, tracker, reasoning IDs, includeUsage, null usage, `[DONE]` and raw handling.
- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaParsing.swift`: null usage, JSON stringify.
- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaEmbeddingModel.swift`: base URL, dimension validation.
- `Packages/swift-ai-alibaba/Sources/SwiftAIAlibaba/AlibabaVideoModels.swift`: request building and warnings in upstream order, errors, media mapping, URL regex, base URL.
- Tests: new `Packages/swift-ai-alibaba/Tests/SwiftAIAlibabaTests/AlibabaUpstreamParityTests.swift` (52 tests, registered in `Porting/map.json`); `AlibabaProviderTests.swift` and `AlibabaProviderLanguageAndVideoTests.swift` updated to the upstream contract (throws instead of warnings, upstream warning texts, null usage, no legacy `toolCallDelta`, generated reasoning IDs).
- Docs: `docs-site/scripts/provider-guides/alibaba.md`, with new native base URL / includeUsage / file-part rules and a "Prompt caching" section.

### Test results

`swift test --package-path Packages/swift-ai-alibaba --no-parallel`: **85 tests passed** (33 at baseline; 52 added).

---

## Parity audit: huggingface, zai, gmicloud, vercel (part of group "compatible")

Upstream paths below are relative to `scratchpad/upstream-all/pkg/<slug>/npm/src` (or `repo-src` for tests).
Swift paths are relative to the repo root.

### @ai-sdk/vercel 3.0.30 -> Packages/swift-ai-vercel

Upstream tests: 0 (the package has no test files). Newly translated: 7 Swift tests built from the matching
`openai-compatible-chat-language-model.test.ts` scenarios the provider inherits ("should pass settings",
"deprecated openai-compatible key", "should include provider-specific options", "should not include ... for
different provider", "top-level reasoning as reasoning_effort", textVerbosity, topK warning, empty content,
stream without a finish reason).

#### Divergences
1. **Provider options ignored, legacy wire mode** - FIXED.
   - Upstream: `vercel-provider.ts:87` builds a plain `OpenAICompatibleChatLanguageModel`, which resolves
     `openai-compatible`/`openaiCompatible`/`vercel` provider options (`openai-compatible-chat-language-model.ts:234`),
     maps top-level `reasoning` to `reasoning_effort`, warns about `topK` (`:262`), accepts `content: null`/`""`,
     and reports a missing stream finish reason as `error`.
   - Swift (before): `VercelProvider.swift:22-23` set `usesGenericOpenAICompatibleProviderOptions = false` and
     `allowsEmptyTextResponse = false`.
   - Effect: `providerOptions["vercel"]`/`["openaiCompatible"]` were silently dropped (no `user`, `reasoning_effort`,
     `verbosity`, custom keys), `reasoning` was not sent, no topK warning, a response with null/empty content threw
     "No text content found", and a cut-off stream finished `other` without an error part.
   - Fix: removed the two legacy flags (generic defaults now apply).
2. **API key resolved at provider creation** (upstream resolves per request in `getHeaders`, `vercel-provider.ts:62`).
   Documented in `docs-site/scripts/provider-guides/vercel.md` ("The key is resolved when the provider is created").
   Not platform-required -> REPORTED (repo-wide convention; zai is the only one of these four that is lazy).
3. Additive Swift settings (`includeUsage`, `supportsStructuredOutputs`, `queryParams`, `transformRequestBody`) do not
   exist upstream; defaults match upstream. Platform/compat additions.

Umbrella `Sources/SwiftAISDK/Providers/VercelCompatibility.swift`: pure pass-through to the package; inherits the fix.
Does not forward `ProviderSettings.environment` (Vercel settings have no `environment` field) - minor, reported.

Tests: `swift test --package-path Packages/swift-ai-vercel --no-parallel` -> 12 tests passed.

### @ai-sdk/gmicloud 3.0.64 -> Packages/swift-ai-gmicloud

Upstream tests: 12 (`gmicloud-chat-language-model.test.ts` 1, `gmicloud-error.test.ts` 7, `gmicloud-provider.test.ts` 4).
Already translated: 12 (GMICloudProviderTests.swift). Newly translated/added: 4 (generic option/reasoning/topK/empty-content
parity plus the "outer message when details is absent" case through a real HTTP 400). Still missing: 0.

#### Divergences
1. **Same legacy wire mode as Vercel** - FIXED. Upstream `gmicloud-chat-language-model.ts` extends
   `OpenAICompatibleChatLanguageModel` without request/response overrides; Swift `GMICloudProvider.swift:37-38` set the
   two legacy flags. Same user-visible effect as Vercel item 1 (providerOptions `gmicloud`/`openaiCompatible` dropped,
   `reasoning` ignored, no topK warning, null content threw). Fix: removed the flags.
2. **Plain-text error bodies**: upstream's error schema rejects GMI's plain-text 404 and `createJsonErrorResponseHandler`
   uses the HTTP status text as the message; Swift uses the body text. Core-wide Swift error mapping -> REPORTED,
   not fixed (not package-local).
3. **Eager API key** (upstream lazy, `gmicloud-provider.ts:73`) - REPORTED, as for Vercel.

Umbrella `GMICloudCompatibility.swift`: pass-through; inherits the fix.

Tests: `swift test --package-path Packages/swift-ai-gmicloud --no-parallel` -> 13 tests passed.

### @ai-sdk/zai 3.0.55 -> Packages/swift-ai-zai

Upstream test cases: 18 (`zai-provider.test.ts` 5; `zai-chat-language-model.test.ts` 12 counting the 3 `it.each`
finish-reason rows; `lazy-schemas.test.ts` 1). Already translated: 14 (provider 5, chat 9). Newly translated: 1 (warning
order, generate + stream). Still missing (platform-only): workflow serialize/restore (no WORKFLOW_SERIALIZE in Swift),
`expectTypeOf` type exports, zod lazy-schema construction.

#### Divergences
1. **Warning order** - FIXED. Upstream order is the base OpenAI-compatible warnings (provider-option deprecations,
   `topK`, `responseFormat`, tool warnings) followed by Z.AI's own (`zai-chat-language-model.ts:178,191`). Swift
   (`ZAILanguageModel.swift`, generate and stream-start) put `topK`/`responseFormat` before the `openai-compatible`
   deprecation warning. Fix: `ZAIPreparedRequest.mergedWarnings` reorders deprecations first. Effect: only warning order
   when the deprecated `openai-compatible` key is combined with topK/responseFormat.
2. Everything else matched: body transform (`do_sample`, `thinking.clear_thinking`, `tool_stream`, `request_id`,
   `user_id`, stripping penalties/seed/user/verbosity), option validation, toolChoice none/required, finish-reason
   mapping, flat/nested error envelopes, `{zai: {}}` provider metadata, http(s) image/video supported URLs, lazy key.
   Note: ZAI emits the "JSON response format schema is only supported with structuredOutputs" warning itself because the
   generic Swift adapter does not (see cross-package item A). If swift-ai-openai-compatible starts emitting it, ZAI
   will report it twice; remove ZAI's copy in `zaiPreparedRequest` at that point.

Umbrella `ZAICompatibility.swift`: pass-through. Tests: `swift test --package-path Packages/swift-ai-zai --no-parallel`
-> 18 tests (4 suites) passed.

### @ai-sdk/huggingface 2.0.93 -> Packages/swift-ai-huggingface

Upstream test cases: 45 (`huggingface-provider.test.ts` 6; `responses/huggingface-responses-language-model.test.ts`
38 counting `it.each` rows; `lazy-schemas.test.ts` 1). Already translated (before this pass, same scenario/assertion):
about 12 (tool choice auto/required/none/tool, provider-defined tool warning, media-type resolution x4, provider-reference
rejection, two stream-error rows, provider aliases). Newly translated: 30 in
`HuggingFaceResponsesUpstreamParityTests.swift` (all doGenerate, doStream, message-conversion, tool-call, structured
output, reasoning, provider-option and tool-preparation scenarios with the upstream fixtures). Still missing:
"create provider with default configuration" without a key (Swift throws at creation, see item 9), the exact
NoSuchModelError messages for embedding/image (Swift uses `AIError.unsupportedModel`), lazy-schemas (platform-only).

#### Divergences (all in `Packages/swift-ai-huggingface/Sources/SwiftAIHuggingFace/HuggingFaceModels.swift`)
1. **`stream: false` missing from generate bodies** - FIXED. Upstream `huggingface-responses-language-model.ts:185`.
   Effect: request body lacked the explicit flag.
2. **2xx body with `error`** - FIXED. Upstream `:212` throws `APICallError` (status 400, message `error.message`,
   `isRetryable: false`, url, request body, raw response body). Swift threw `AIError.invalidResponse`. Now
   `AIError.apiCall` with those fields.
3. **Generate content shape/order** - FIXED. Upstream (`:229` onwards) builds content in output order: text parts with
   `providerMetadata.huggingface.itemId`, sources right after their text, reasoning with itemId, function/MCP tool
   call followed by its result. Swift returned synthesized content (reasoning, text, sources, tool calls, tool results)
   without item IDs, added `itemId` metadata to tool results, fell back to `output_text`, and threw
   "No Hugging Face response output found" when `output` was empty. Effect: wrong content order/metadata, invented text
   from `output_text`, spurious errors on empty output (upstream returns empty content).
4. **Usage** - FIXED. Upstream `convertHuggingFaceResponsesUsage` reports `cacheRead: 0`, `reasoning: 0`,
   `text = output - reasoning`; Swift used the generic parser (nil cache/reasoning).
5. **Assistant input conversion** - FIXED. Upstream `convert-to-huggingface-responses-messages.ts:82,100` sends one
   assistant message per text and per reasoning part and nothing for tool calls/results; Swift sent one combined
   message (dropping reasoning) and an empty `{role: assistant, content: []}` for tool-only turns.
6. **Tool messages warning** - FIXED: upstream warns once per tool message (`:112`); Swift warned once in total.
7. **Tools** - FIXED. Upstream keeps `tools: []` and `tool_choice` when every declared tool is provider-defined
   (`huggingface-responses-prepare-tools.ts:31,91`); Swift omitted both. Swift also leaked tool metadata keys
   (`description`, `strict`, `providerOptions`, `inputExamples`) into `parameters`; now stripped. Tools are sorted by
   name because Swift's tool dictionary is unordered (upstream keeps call order; platform limitation).
8. **Stream part sequence** - FIXED. Upstream (`:405` onwards): `stream-start` always first (even with no warnings),
   `response-metadata` only from `response.created`, no raw chunks (includeRawChunks is ignored upstream), text/reasoning
   deltas without provider metadata, text-end/reasoning-end without metadata, MCP items not streamed, processing continues
   after `response.completed`, `response.incomplete` not special-cased, finish metadata always
   `{huggingface: {responseId}}` with the id from `response.created`/`response.completed` (null otherwise). Swift
   emitted an HTTP-head response-metadata before an optional stream-start, raw chunks, metadata on deltas/ends, MCP
   tool-input/call/result parts, stopped at `response.completed`, mapped `response.incomplete`, and returned empty finish
   metadata without a completed event. Kept as Swift stream-validity normalization (documented in code): a synthetic
   text/reasoning start before an orphan delta and closing still-open blocks before finish. Also emits
   `.requestMetadata` after stream-start (Swift equivalent of upstream `request: { body }`).
9. **Eager API key** (upstream lazy, `huggingface-provider.ts:72`) - REPORTED.
10. **User-Agent**: upstream adds no provider suffix (only provider-utils' runtime UA); Swift sends
    `ai-sdk/huggingface/2.0.82` (invented, and stale vs 2.0.93). REPORTED, not changed (no Swift equivalent of the
    provider-utils UA; touching it changes an existing documented-by-test header).
11. **Lenient response validation**: upstream zod requires `object`, `tools`, `temperature`, ... in the response;
    Swift parses leniently. REPORTED (not fixed).
12. Swift extras kept: `extraBody` passthrough, `apiKeyProvider`, deterministic source IDs
    (`huggingface-source-N` instead of `generateId`).

Docs: `docs-site/scripts/provider-guides/huggingface.md` updated (content order, `output_text` ignored, no MCP/raw stream
parts, body-error behavior).

Umbrella `HuggingFaceCompatibility.swift`: pass-through; does not forward `environment` (HF settings have none) - minor.

Tests: `swift test --package-path Packages/swift-ai-huggingface --no-parallel` -> 45 tests passed. One existing test fixture
(`huggingFaceLanguageDefaultsToResponsesEndpoint`) was changed from an `output_text`-only body to an `output` message,
since `output_text` is no longer read. Root tests that touch HF (`WeeklyStructuredOutput20261025Tests`,
`WeeklyLanguage20261025Tests`) were read and remain compatible (not run).

### Cross-package items for swift-ai-openai-compatible (owner: parent agent) - REPORTED

A. Generic chat does not emit the upstream warning `{type: unsupported, feature: responseFormat, details: "JSON response
   format schema is only supported with structuredOutputs"}` when a JSON schema is requested without structured outputs
   (`openai-compatible-chat-language-model.ts:273`). Verified with Vercel: `warnings == []`. Affects vercel, gmicloud and
   every generic wrapper.
B. Generic chat omits the empty provider-metadata namespace: upstream always returns `providerMetadata: {[metadataKey]: {}}`
   in generate and stream finish (`:493`, stream `providerMetadata[providerOptionsName] = {}`); Swift returns `[:]`
   (verified with Vercel). ZAI patches this locally.

### Files changed
- Packages/swift-ai-vercel/Sources/SwiftAIVercel/VercelProvider.swift
- Packages/swift-ai-vercel/Tests/SwiftAIVercelTests/VercelOpenAICompatibleChatParityTests.swift (new)
- Packages/swift-ai-vercel/Porting/map.json
- Packages/swift-ai-gmicloud/Sources/SwiftAIGMICloud/GMICloudProvider.swift
- Packages/swift-ai-gmicloud/Tests/SwiftAIGMICloudTests/GMICloudOpenAICompatibleChatParityTests.swift (new)
- Packages/swift-ai-gmicloud/Porting/map.json
- Packages/swift-ai-zai/Sources/SwiftAIZAI/ZAILanguageModel.swift
- Packages/swift-ai-zai/Tests/SwiftAIZAITests/ZAIWarningOrderTests.swift (new)
- Packages/swift-ai-zai/Porting/map.json
- Packages/swift-ai-huggingface/Sources/SwiftAIHuggingFace/HuggingFaceModels.swift
- Packages/swift-ai-huggingface/Tests/SwiftAIHuggingFaceTests/HuggingFaceResponsesUpstreamParityTests.swift (new)
- Packages/swift-ai-huggingface/Tests/SwiftAIHuggingFaceTests/HuggingFaceProviderTests.swift (one fixture)
- Packages/swift-ai-huggingface/Porting/map.json
- docs-site/scripts/provider-guides/{vercel,gmicloud,huggingface}.md

### Test results
vercel 12/12, gmicloud 13/13, zai 18/18 (4 suites), huggingface 45/45 - all `--no-parallel`, all passing.

---

## Parity audit: baseten, cerebras, deepinfra, fireworks

Upstream sources: `upstream-all/pkg/<slug>/npm/src` (baseline) and `repo-src` (matching-release tests).
Paths below: `U:` = upstream (pkg-relative), `S:` = Swift (repo-relative, pre-fix line numbers where code changed).
Counts are `it`/`it.each` cases per file (an `it.each` row set is counted once).

### @ai-sdk/baseten → Packages/swift-ai-baseten

Upstream tests: ~59 (chat 6 × doGenerate/doStream, embedding 11, provider.unit 42).
- Already translated (behavior level): ~22 (chat JSON fallback 3 cases in Weekly20261108JSONTests; embedding extract/usage/body/bearer/both modelURL forms/string+object errors; provider URL, headers, user agent, /predict rejection, missing modelURL, image unsupported, includeUsage stream, structured outputs).
- Newly translated: 8 (`BasetenUpstreamParityTests`: schema-in-prompt with message/warning assertions, text unchanged, other models keep JSON schema, dedicated unchanged — each for generate+stream; `basetenEmbeddingAccepts128Values…`, `basetenEmbeddingRejectsMoreThan128Values…`).
- Still missing: performance-client path (9 cases) — platform-only (NAPI addon `@basetenlabs/performance-client`, no Swift equivalent); ~20 provider.unit cases that assert constructor arguments of mocked `OpenAICompatibleChatLanguageModel`/`errorStructure.errorSchema.safeParse` (JS-internal; observable behavior covered by request/error tests); "real response headers" (not re-asserted).

Divergences:
1. Embedding batch limit. U: `openai-compatible/npm/src/embedding/openai-compatible-embedding-model.ts:149` throws `TooManyEmbeddingValuesForCallError` above `maxEmbeddingsPerCall` (128); test `baseten-embedding-model.test.ts` "should reject more than 128 values". S: `Packages/swift-ai-baseten/Sources/SwiftAIBaseten/BasetenModels.swift:30-50` split >128 values into several HTTP requests inside one `embed` call and synthesized a combined raw body. Verdict: **fixed** (single request, throws `AITooManyEmbeddingValuesForCallError`; `embedMany` still splits via `maxEmbeddingsPerCall`). Effect: direct `embed` of 129+ values now fails like upstream instead of silently fan-out; `rawValue` is the real response body.
2. DeepSeek-V4-Pro-0813 JSON transform skipped for a plain `/sync` `modelURL`. U: `baseten/npm/src/baseten-provider.ts:245,267` (non-`/sync/v1` URLs fall through to the Model APIs model, which carries `transformBasetenRequestBody`). S: `BasetenProvider.swift:111` applied it only when `modelURL == nil`. Verdict: **fixed**. Effect: JSON+reasoning requests on that path now get prompt-injected JSON + compatibility warning.
3. Empty-text responses rejected. U: `openai-compatible-chat-language-model.ts:446-458` returns empty content when `message.content` is null. S: `BasetenProvider.swift:104` `allowsEmptyTextResponse = false` threw "No text content found". Verdict: **fixed** (`true`). Effect: reasoning-only / length-truncated answers no longer throw.
4. Minor, not fixed: Swift rejects an empty `values` list before the request (`BasetenModels.swift:24`); upstream would send it. Local guard, low impact — **reported**.
5. Minor, not fixed (shared openai-compatible behavior): embedding body merges all `providerOptions.baseten` keys; upstream embedding sends only `dimensions`/`user` (`openai-compatible-embedding-model.ts:~165`). Owned by the openai-compatible package helper `openAICompatibleProviderOptions` — **reported**.

### @ai-sdk/cerebras → Packages/swift-ai-cerebras

Upstream tests: ~38 (chat-language-model 25, provider 13).
- Already translated: ~25 (max_completion_tokens, provider-option mapping, service tier/queue threshold header/precedence/validation/pass-through, stream tier metadata, reasoning_content→reasoning, errors, aliases, unsupported embedding/image).
- Newly translated: 8 (`CerebrasUpstreamParityTests` with verbatim fixtures in `CerebrasUpstreamFixtures.swift`: three doGenerate fixture snapshots, streamed fixture finish/usage/metadata + no tool-call parts, two "does not fabricate serviceTier" cases; plus local: reasoning-only response, empty choices, `provider-default`).
- Still missing: `exports the constrained Cerebras provider options type` (TS `expectTypeOf`, platform-only); metadata-extractor unit tests (internal JS object; behavior covered through results).

Divergences:
1. Streamed JSON mode emitted spurious tool calls. U: `cerebras/npm/src/cerebras-chat-language-model.ts:127-134` drops all tool parts once text streamed in JSON mode; tool calls finalize only on flush (`provider-utils/npm/src/streaming-tool-call-tracker.ts:428-432`). S: `CerebrasModels.swift` emitted `toolInputEnd`/`toolCall` from `finishedParts()` for calls that started before the text. Verdict: **fixed** (finished tool parts suppressed when JSON mode + text). Existing test `cerebrasLanguageStreamsToolCallsAndDropsStructuredRepeat` encoded the old behavior and was corrected. Effect: structured-output streams no longer surface a tool call the non-streaming path drops.
2. doGenerate filter ignored the raw finish reason. U: `cerebras-chat-language-model.ts:37` requires `rawFinishReason === 'tool_calls'`. S: `CerebrasModels.swift:~53` dropped tool calls for any finish. Verdict: **fixed**.
3. No-text response threw. U: openai-compatible returns empty content; only empty `choices` throws "Response did not contain any choices." S: `CerebrasModels.swift:36-38`. Verdict: **fixed**.
4. `reasoning: "provider-default"` was sent as `reasoning_effort: "provider-default"`. U: `openai-compatible-chat-language-model.ts:296` (`isCustomReasoning`). S: `CerebrasRequestOptions.swift:~254`. Verdict: **fixed**.
5. `reasoning: "none"` is not sent (upstream sends `reasoning_effort: "none"`). Documented in `docs-site/scripts/provider-guides/cerebras.md` but not platform-required. Verdict: **documented-intentional, reported (not fixed)**.
6. `providerOptions.openaiCompatible` accepts Cerebras-specific keys (`parallelToolCalls`, `serviceTier`, …) and passes unknown keys; upstream only reads `user/reasoningEffort/textVerbosity/strictJsonSchema` there and passes through only `cerebras` keys. Documented in the guide. **Reported**.
7. Provider metadata: Swift adds `cerebras.logprobs` (not in upstream) and returns `[:]` instead of `{cerebras: {}}` when empty. **Reported** (additive/minor).
8. Strict JSON schema gets `additionalProperties: false` added (`CerebrasRequestOptions.swift` `cerebrasResponseFormat`); upstream forwards the schema unchanged. Same pattern as Swift openai-compatible (`OpenAICompatibleChatCommon.swift`) — **reported** to the openai-compatible owner.

### @ai-sdk/deepinfra → Packages/swift-ai-deepinfra

Upstream tests: ~28 (chat 2, image 14 + capabilities it.each, provider 10).
- Already translated: ~22 (Gemma usage fix generate/stream, non-Gemma unchanged, aliases/URLs/custom baseURL, image params/size/URL/headers/edit/multi-image/mask/provider options, one image per call).
- Newly translated: 2 upstream ("should handle API errors" for generation, edit error message) + 3 local parity cases.
- Still missing: abort-signal test (covered generically by core), `response metadata` timestamp injection via `_internal.currentDate` (JS-internal clock hook).

Divergences:
1. Native chat ignored `providerOptions["deepinfra"]` and portable `reasoning`. U: `deepinfra/npm/src/deepinfra-chat-language-model.ts` extends `OpenAICompatibleChatLanguageModel` (getArgs `openai-compatible-chat-language-model.ts:209-337`). S: `Packages/swift-ai-deepinfra/Sources/SwiftAIDeepInfra/DeepInfraProvider.swift:89` `usesGenericOpenAICompatibleProviderOptions = false` (only `extraBody` was read). Verdict: **fixed**. Effect: `user`, `reasoningEffort`, passthrough keys and `reasoning` now reach the body, as the guide already promised.
2. No-text responses threw (`DeepInfraProvider.swift:90`). **Fixed** (as baseten #3).
3. Image error messages. U: `deepinfra-image-model.ts:164` (`detail.error`) and `:127` (`error.message ?? 'Unknown error'`). S: `DeepInfraModels.swift` used the raw body. **Fixed** (`deepInfraImageHTTPError`).
4. Platform note: Swift core has no `maxImagesPerCall` splitting, so `count > 1` throws before the request instead of being split into n calls (documented in guide). **Platform-only/documented**.

### @ai-sdk/fireworks → Packages/swift-ai-fireworks

Upstream tests: ~64 (chat 7, image 31 + capabilities it.each, provider 26).
- Already translated: ~45 (reasoning maps/exclusions/warnings incl. stream-start, prepareRequest, thinking/promptCacheKey/serviceTier/reasoningHistory transforms and precedence, includeUsage, structured outputs, error envelopes for chat/completion/embedding, image URLs/params/warnings/size/edit/async polling/timeouts/abort/errors/metadata).
- Newly translated: 3 upstream (`should reject invalid provider options`, typed workflow options, capabilities it.each) + out-of-schema cases + reasoning-only chat.
- Still missing: construction-introspection cases in provider.test.ts (JS-internal config objects; behavior covered), `custom fetch` (transport injection is the Swift equivalent and is used throughout).

Divergences:
1. Image provider options not validated. U: `fireworks-image-model.ts:179` `parseProviderOptions` with `fireworks-image-model-options.ts` (e.g. `output_format` enum, `safety_tolerance` 0–6 int). S: `FireworksModels.swift` merged options unchecked. Verdict: **fixed** (`fireworksValidateImageProviderOptions`; unknown keys still pass, as with `z.looseObject`). Effect: invalid options throw `AIError.invalidArgument` ("invalid fireworks provider options…") before any request.
2. No-text chat responses threw (`FireworksProvider.swift:90`). **Fixed**.

### Umbrella (`Sources/SwiftAISDK/**`, read-only) — reported, not fixed

- U1 Baseten DeepSeek-V4-Pro-0813 JSON transform missing: `Providers/OpenAICompatibleProvider.swift:167-168` builds `OpenAICompatibleChatModel` from `basetenChatConfig` (`OpenAICompatibleProviderHelpers.swift:12-16`) with only the user's transforms; `basetenTransformJSONReasoning` is never installed. Effect: `AIProviders.baseten()` (the guide's quick start) sends `response_format` with reasoning, the bug upstream works around.
- U2 Baseten and DeepInfra ignore `providerOptions` and portable `reasoning`: `OpenAICompatibleProvider.swift:89` passes `usesGenericOpenAICompatibleProviderOptions: usesOpenAICompatibleSurfaceIDs` (false for `ProviderRegistry.swift:260-265`). Same bug fixed natively in deepinfra (#1). (By code reading; root tests not run.)
- U3 Empty-text responses throw for all umbrella OpenAI-compatible wrappers: `Models/OpenAICompatibleConfig.swift:69` defaults `allowsEmptyTextResponse` to false.
- Capability lists: Fireworks/DeepInfra/Baseten all JSON-schema=true upstream; umbrella sets true for baseten/deepinfra (`OpenAICompatibleProvider.swift:80`) and fireworks (`ProviderRegistry.swift:240`). Cerebras uses the native model (always JSON schema). No list bug found.

### Files changed

- Packages/swift-ai-baseten/Sources/SwiftAIBaseten/BasetenModels.swift, BasetenProvider.swift
- Packages/swift-ai-baseten/Tests/SwiftAIBasetenTests/BasetenProviderTests.swift (batching test replaced), BasetenUpstreamParityTests.swift (new)
- Packages/swift-ai-cerebras/Sources/SwiftAICerebras/CerebrasModels.swift, CerebrasRequestOptions.swift
- Packages/swift-ai-cerebras/Tests/SwiftAICerebrasTests/CerebrasProviderTests.swift (stream expectation corrected), CerebrasUpstreamParityTests.swift, CerebrasUpstreamFixtures.swift (new)
- Packages/swift-ai-deepinfra/Sources/SwiftAIDeepInfra/DeepInfraProvider.swift, DeepInfraModels.swift
- Packages/swift-ai-deepinfra/Tests/SwiftAIDeepInfraTests/DeepInfraUpstreamParityTests.swift (new)
- Packages/swift-ai-fireworks/Sources/SwiftAIFireworks/FireworksProvider.swift, FireworksModels.swift
- Packages/swift-ai-fireworks/Tests/SwiftAIFireworksTests/FireworksUpstreamParityTests.swift (new)
- Porting/map.json of all four packages (new test files; baseten chat test registered)
- docs-site/scripts/provider-guides/baseten.md (embedding batch sentence)

### Test results (`swift test --package-path Packages/<pkg> --no-parallel`)

- swift-ai-baseten: 26 tests, passed
- swift-ai-cerebras: 42 tests, passed
- swift-ai-deepinfra: 20 tests, passed
- swift-ai-fireworks: 24 tests, passed

---

### Final test table (all `swift test --package-path Packages/<pkg> --no-parallel`, after every change)

| Package | Result |
|---|---|
| swift-ai-openai-compatible | 40 passed (was 16) |
| swift-ai-deepseek | 78 passed |
| swift-ai-alibaba | 85 passed |
| swift-ai-moonshotai | 116 passed |
| swift-ai-perplexity | 69 passed |
| swift-ai-baseten | 26 passed |
| swift-ai-cerebras | 42 passed |
| swift-ai-deepinfra | 20 passed |
| swift-ai-fireworks | 24 passed |
| swift-ai-gmicloud | 13 passed |
| swift-ai-huggingface | 45 passed |
| swift-ai-zai | 18 passed |
| swift-ai-vercel | 12 passed |
| other dependents of openai-compatible (not edited): google-vertex 56, tencent 25, togetherai 46, xai 63, openai 340 | passed |

Not run: root umbrella/compatibility suite (disk), azure, amazon-bedrock (both use the OpenAI wire profile / `usesGeneric=false`, which the changes do not touch).
`node Scripts/sdk.mjs catalog validate` currently fails on an unowned anthropic test file from another group, not on this group.

## Audio and embedding providers

## Parity audit: audio group

Combined report. ElevenLabs, Deepgram and Cartesia were audited by forked sub-agents; the rest by the group agent.


## @ai-sdk/elevenlabs → Packages/swift-ai-elevenlabs

Baseline: npm 3.0.86 (src == repo-src at test ref 8bc7652c). Upstream files: `npm/src/*`, tests in `repo-src/*.test.ts`.

### Upstream test cases (counted by `it`/`it.each` declarations)

| File | Total | Already translated | Newly translated | Still missing / excluded |
| --- | --- | --- | --- | --- |
| elevenlabs-speech-model.test.ts | 42 | 5 (empty alignment arrays, dialogue voice segments, language, speed, instructions) | 37 | 0 |
| elevenlabs-speech-stream.test.ts | 35 | 2 (countCodePoints, cancel closes socket — partial) | 28 | 5: three fake-timer keepalive cases (idle keepalive, none with inactivityTimeout, dialogue keepalive x2 incl. buffered v3) and "close the socket on abort" — the shared core `SpeechSocketSession` uses a wall-clock 15 s idle check that tests cannot advance; abort is core session behaviour |
| elevenlabs-transcription-model.test.ts | 33 | 1 (sourceUrl warning) | 15 | 17: 16 `doStream` (Scribe v2 Realtime) cases — feature not implemented (documented deferred gap, reported below); 1 "real date when no custom date provider" — Swift has no `currentDate` injection (platform) |
| elevenlabs-music-response.test.ts | 7 | 5 (part order, quoted boundary, optional metadata, empty audio, missing parts) | 2 (invalid content types, malformed metadata) | 0 |
| elevenlabs-error.test.ts | 7 | 5 handler cases (Weekly20261101SpeechTests) | 0 (speech/transcription error surfacing added in parity suites) | 2 schema-only `safeParseJSON` cases: out-of-scope (no zod schema object; behaviour covered via the handler) |
| lazy-schemas.test.ts | 1 | – | – | out-of-scope (JS lazy schema) |
| elevenlabs-speech-model-options.test-d.ts | type test | – | – | out-of-scope (TS types) |
| **Total** | **125** | **18** | **82** | **25** (22 missing, 3 out-of-scope) |

### Divergences

All Swift line numbers refer to the files after this change.

| # | Upstream evidence | Swift evidence | Verdict | User-visible effect |
| --- | --- | --- | --- | --- |
| 1 | transcription-model-options.ts:19 (`diarize ... .default(true)`), transcription-model.ts:167 | ElevenLabsAudioModels.swift transcription defaults (`diarize` was `.bool(false)`), now ~line 421 | fixed | Any call with `providerOptions.elevenlabs` (e.g. only `languageCode`) sent `diarize=false`, disabling speaker labels; upstream sends `true`. An existing Swift test encoded the bug and was corrected. |
| 2 | transcription-model.ts:200-204 | ElevenLabsAudioModels.swift `transcribe` guard | fixed | `scribe_v2_realtime` was POSTed to the batch endpoint; now rejected before HTTP (`AIError.invalidArgument(argument: "model", "'non-streaming transcription with scribe_v2_realtime' functionality not supported.")`). |
| 3 | transcription-model.ts:129-136, options schema :22-38 | ElevenLabsAudioModels.swift transcription keys/validation | fixed | Batch `streaming` options were silently dropped (no warning, no validation); now validated and warned (`unsupported`, `providerOptions.elevenlabs.streaming`). |
| 4 | transcription-model.ts:233-238 | ElevenLabsTranscriptionParsing.swift `elevenLabsTranscriptionSegments` | fixed | Words with empty `text` were dropped from `segments`; upstream maps every word. |
| 5 | transcription-model.ts:251-256 + response schema :752-777 (zod strips unknown keys) | ElevenLabsTranscriptionParsing.swift `elevenLabsSchemaWord` | fixed | `providerMetadata.elevenlabs.words` leaked unknown keys such as `logprob`; now projected to `text,type,start,end,speaker_id,characters` (raw body unchanged). |
| 6 | transcription-model.ts:138-189 | ElevenLabsAudioModels.swift multipart loop (was `for (key, value) in options`) | fixed | Multipart field order was dictionary-random; now `model_id, file/source_url, diarize, language_code, tag_audio_events, num_speakers, timestamps_granularity, file_format`. |
| 7 | speech-model.ts:126-143, 253-259 | ElevenLabsAudioModels.swift `speak` | fixed | TTS warnings: instructions came first and streaming/dialogue/music/sound-only warnings used a generic "ElevenLabs ignores X…" text; now upstream order and `details` text. |
| 8 | speech-model.ts:293-320 (dialogue), 404-427 (music/sfx), 450-456 | ElevenLabsStreamingSpeechModel.swift `elevenLabsSpecialSpeech` | fixed | Dialogue/music/sound-effects warnings had different texts and order (e.g. text-prompt warning, `voice`, `applyLanguageTextNormalization`; getArgs warnings now precede dialogue ones). |
| 9 | speech-model.ts:442-448 | `elevenLabsSpecialSpeech` | fixed | compositionPlan conflict error argument/message now `providerOptions.elevenlabs.<option>` / "ElevenLabs music <option> cannot be combined with compositionPlan." (forceInstrumental checked first). |
| 10 | speech-model.ts:286-291 | `elevenLabsSpecialSpeech` | fixed | Non-dialogue model error message now "…; <model> is not one." |
| 11 | speech-model.ts:540-541 (URLSearchParams order), 694-713 | ElevenLabsAudioModels.swift `elevenLabsQuerySuffix`; streaming `queryValues` | fixed | HTTP and WebSocket query strings were alphabetically sorted (`enable_logging=…&output_format=…`); now upstream insertion order. Four existing Swift URL assertions updated. |
| 12 | speech-model.ts:166-236, 210 (truthiness checks) | `speak`, `elevenLabsPronunciationLocators` | fixed | Empty `language`/`languageCode`/`previousText`/`nextText`/`applyTextNormalization`/`versionId` were sent as empty strings; upstream omits them. |
| 13 | speech-model.ts:632-680, 717-722, 927-930 | ElevenLabsStreamingSpeechModel.swift `stream`, `elevenLabsStreamOutputFormat` | fixed | Streaming rejection messages (music/sfx, dialogue requirements, conversational voice count, unversioned locator, unlisted call voice, unsupported output format) now match upstream; check order aligned (voice check after URL build). |
| 14 | speech-model.ts:826-887 | `elevenLabsStreamWarnings` | fixed | Streaming warnings: instructions text differed; HTTP-only list ordered sound before music; dialogue warnings used wrong features/texts (`providerOptions.elevenlabs.speed` vs `speed`). |
| 15 | speech-model.ts:769-785 | `stream` dialogue init message | fixed | Dialogue init sent `voice_settings: {}` when `dialogue.voiceSettings` lacked `stability`; now omitted. |
| 16 | speech-stream.ts:215-224 | `ElevenSpeechState.sendText.emit` | fixed | **Wire bug:** every dialogue input without a new turn was sent with `"new_turn": null` (Swift nil literal → JSON null) instead of omitting the key. |
| 17 | speech-stream.ts:245-297 | `ElevenSpeechState.decode`, `elevenLabsStreamErrorText` | fixed | TTS frames carrying audio plus `error` were treated as errors; dialogue alignment emitted `null` keys; TTS honoured `is_final_audio_for_turn` and dialogue `isFinal`/`normalizedAlignment` (upstream: protocol-specific); non-string `error` now JSON-stringified. |
| 18 | speech-stream.ts:75-84, 166-173, 204-212 | `sendText` | fixed | Text-part voice / `newTurn` error messages now match upstream. |
| 19 | speech-stream.ts:528-538 | `elevenLabsStreamConnectionError` | fixed (in package) | Early close now reports "ElevenLabs speech stream closed before completion (code …)." instead of the generic core text. |
| 20 | transcription-model.ts:261-781 (`doStream`) | no Swift realtime STT | reported | Scribe v2 Realtime streaming transcription is absent. Documented as deferred in `Docs/PortingStatus.md` (P1) but not platform-required (other packages implement `StreamingTranscriptionModel` over `AIDuplexWebSocketTransport`). Needs a new feature port. |
| 21 | speech-stream.ts:492-502 | core `SpeechSocketSession` (decode cannot yield then throw) | reported (core) | With `includeRawChunks`, upstream emits the raw error frame before failing; Swift fails without that raw part. |
| 22 | speech-stream.ts:525-527 | core `SpeechSocketSession` | reported (core/platform) | Socket transport errors surface the transport error rather than "ElevenLabs speech stream error.". |
| 23 | provider.ts:122-145; speech-model.ts UnsupportedFunctionalityError | `AIError.unsupportedModel` / `AIError.invalidArgument` | platform-only | No Swift `NoSuchModelError`/`UnsupportedFunctionalityError` for audio; messages kept upstream-equal. |
| 24 | – | `ElevenLabsMusicModel`, `ElevenLabsSoundEffectsModel`, voice changer/isolator, dubbing, `baseURL`/`queryParams`, `extraBody` passthrough | documented-intentional (Swift-only additive) | No upstream counterpart; unchanged. |

Umbrella check (read-only): `Sources/SwiftAISDK/Providers/ElevenLabsCompatibility.swift`, `ProviderRegistry.swift:369`, `OpenAICompatibleProvider.swift` (routing at 509/545/567/591-635, user-agent `ai-sdk-elevenlabs/3.0.86` at 765) delegate to the package models; no divergence found. The umbrella has no ElevenLabs `streamingTranscriptionModel`, consistent with item 20.

### Files changed

- Packages/swift-ai-elevenlabs/Sources/SwiftAIElevenLabs/ElevenLabsAudioModels.swift
- Packages/swift-ai-elevenlabs/Sources/SwiftAIElevenLabs/ElevenLabsStreamingSpeechModel.swift
- Packages/swift-ai-elevenlabs/Sources/SwiftAIElevenLabs/ElevenLabsTranscriptionParsing.swift
- Packages/swift-ai-elevenlabs/Tests/SwiftAIElevenLabsTests/ElevenLabsProviderTests.swift (4 URL-order assertions, diarize default)
- New: Tests/SwiftAIElevenLabsTests/ElevenLabsSpeechModelParityTests.swift, ElevenLabsSpeechStreamParityTests.swift, ElevenLabsSpeechDialogueStreamParityTests.swift, ElevenLabsTranscriptionParityTests.swift (registered in Porting/map.json)
- Packages/swift-ai-elevenlabs/Porting/map.json
- docs-site/scripts/provider-guides/elevenlabs.md (diarize default wording, words metadata fields, realtime rejection, `voiceSettings.speed` row)

### Test results

`swift test --package-path Packages/swift-ai-elevenlabs --no-parallel`: 99 tests in 10 suites passed (parameterized tests counted once). docs-site check/build not run.


### @ai-sdk/deepgram (3.1.53) -> Packages/swift-ai-deepgram

Upstream: `npm/src` (identical to `repo-src` sources). Paths below: `U/` = `scratchpad/upstream-all/pkg/deepgram/npm/src/`, `S/` = `Packages/swift-ai-deepgram/Sources/SwiftAIDeepgram/`.

#### Upstream test cases (68 `it`/`it.each` blocks)

| File | Total | Already translated | Newly translated | Still missing (reason) |
| --- | --- | --- | --- | --- |
| deepgram-transcription-model.test.ts | 13 | 7 (headers, diarize x2, detectLanguage query, keyterm/paragraphs/..., detected language, real date/modelId) | 6 (fixture text, usage seconds, response metadata snapshot fields, inline `sv`, undefined language, keyterm block exact) | 0 |
| deepgram-speech-model.test.ts | 28 | 22 | 6 (callback rejection x2 message+no call, callbackMethod warning text, empty metadata/usage, request body, instructions warning, err_msg APICallError) | 0 |
| deepgram-streaming-transcription.test.ts | 24 | 16 (Weekly20261108DeepgramTests) | 6 (revisable/final mapping exact, batch-only warnings order, disabled options no warning, raw-format rejection message, Bearer/bearer/Basic, close code+reason message) | 2 platform-only: base64 string audio chunks (Swift input is `Data`); "omits undefined headers" (Swift headers are non-optional and the provider always sets `authorization`). Rate `1.5` sub-case unrepresentable (`sampleRate: Int`). |
| deepgram-error.test.ts | 2 | 0 | 2 (asserted through HTTP error surfacing: `err_msg` with and without `request_id`) | 0 |
| lazy-schemas.test.ts | 1 | - | - | out-of-scope (zod lazy-schema caching) |

New file: `Tests/SwiftAIDeepgramTests/DeepgramUpstreamParityTests.swift` (21 tests, registered in `Porting/map.json`).

#### Divergences

| # | Upstream evidence | Swift evidence (after fix) | Verdict | User-visible effect |
| --- | --- | --- | --- | --- |
| 1 | U/deepgram-transcription-model.ts:79-85 warning `details` "Deepgram batch transcription does not support streaming options." | S/DeepgramAudioModels.swift:45 (was "Streaming options are ignored for non-streaming transcription.") | fixed | Warning text now matches. |
| 2 | U/deepgram-transcription-model.ts:154,183-186 `durationInSeconds = metadata.duration ?? undefined` | S/DeepgramAudioModels.swift:44 (was falling back to max word end) | fixed | `durationInSeconds` is nil when Deepgram returns no `metadata.duration`, instead of an invented value. |
| 3 | U/deepgram-speech-model.ts:79-94 callback error message / callbackMethod warning text | S/DeepgramAudioModels.swift:292-304 | fixed | Error and warning text match upstream (tests check "returns a JSON acknowledgement instead of audio"). |
| 4 | U/deepgram-speech-model.ts:269-285 container warnings interpolate the caller's original `container` | S/DeepgramAudioModels.swift:492-510 (was lowercased) | fixed | Warning shows e.g. `Container "WAV"`. |
| 5 | U/deepgram-speech-model.ts:256,263,443 truthiness checks on `encoding`, `container`, `tag` | S/DeepgramAudioModels.swift:340-345, `deepgramNonEmptyQueryValue` | fixed | Empty-string encoding/container/tag are ignored instead of sending `encoding=` / `tag=`. |
| 6 | U/deepgram-speech-model.ts:344-388 `sampleRate` any number, `String(sampleRate)` | S/DeepgramAudioModels.swift `deepgramApplySampleRate(_: Double, ...)` (was `.intValue`, silently dropping non-integers) | fixed | Non-integer sample rates now warn/pass exactly like upstream. |
| 7 | U/deepgram-speech-model.ts:391-437 `Number(bitRate)` (NaN passes opus/aac range checks) | S/DeepgramAudioModels.swift:549-552 (was `Int(bitRate) ?? 0`) | fixed | Bit-rate validation for string/decimal values matches JS. |
| 8 | U/deepgram-speech-model.ts:479 `if (instructions)` | S/DeepgramAudioModels.swift:417 (was `!= nil`) | fixed | Empty `instructions` no longer warns. |
| 9 | U/deepgram-streaming-transcription.ts:53-64 single `inputAudioFormat` error | S/DeepgramStreamingTranscriptionModel.swift:28-32 | fixed | Same argument and message ("Deepgram streaming requires ..."). |
| 10 | U/deepgram-streaming-transcription.ts:88-120 iterate parsed options in schema order; warning text "...for Deepgram streaming transcription." | S/DeepgramStreamingTranscriptionModel.swift:49-57 (was random `Dictionary` order, different text) | fixed | Deterministic warning order (e.g. detectLanguage before summarize) and query parameter order; warning text matches. |
| 11 | U/deepgram-streaming-transcription.ts:134-140 `argument: 'headers'`, "must use the Token or Bearer scheme." | S/DeepgramStreamingTranscriptionModel.swift:64 | fixed | Error matches. |
| 12 | U/deepgram-streaming-transcription.ts:280-284, 352-363 error/close messages | S/DeepgramStreamingTranscriptionModel.swift:143,149,182 | fixed | "Deepgram streaming transcription failed." fallback; "Deepgram streaming connection closed unexpectedly (code): reason" (no trailing period after a reason). |
| 13 | U/deepgram-streaming-transcription.ts:305-309 nullish `channel` -> "missing a transcript alternative" | S/DeepgramStreamingTranscriptionModel.swift:197-206 (was generic invalid-event) | fixed | Missing channel/alternatives produce the upstream message. |
| 14 | U/deepgram-streaming-transcription.ts:315-317 `speech_final ?? false` | S/DeepgramStreamingTranscriptionModel.swift:214 (was forwarding JSON `null`) | fixed | `providerMetadata.deepgram.speechFinal` is `false` for null/missing. |
| 15 | U/deepgram-streaming-transcription.ts:145,295 single timestamp for result and all `response-metadata` parts | S/DeepgramStreamingTranscriptionModel.swift:67-71,188 | fixed | Response metadata timestamps are consistent. |
| 16 | U/deepgram-streaming-transcription.ts:41-43 `UnsupportedFunctionalityError` for Flux | S/DeepgramStreamingTranscriptionModel.swift:27 `AIError.invalidArgument` | reported (no core UnsupportedFunctionality error type for transcription) | Error type differs; message still names Flux. |
| 17 | U/deepgram-transcription-model.ts:111-116 `URLSearchParams` insertion order (model first) | batch `/v1/listen` and `/v1/speak` query use shared `queryString` (alphabetical) | platform-only/acceptable (server ignores order; changing the shared helper is core) | Query parameter order differs on the wire only. |
| 18 | U/deepgram-provider.ts (provider.transcription supports `doStream`) | Umbrella `Sources/SwiftAISDK/Providers/ProviderRegistry.swift:361` (`AIProviders.deepgram(settings:)` -> `OpenAICompatibleProvider`), `OpenAICompatibleProvider.swift:528-535` throws for non-xAI streaming | reported (umbrella, read-only) | Umbrella Deepgram factory cannot stream; only the native `AIProviders.deepgram(configuration:)` can. Capability-matrix note already says "native provider"; consider documenting or routing. |

Swift extensions relied on (not upstream): legacy `extraBody` / nested `extraBody["deepgram"]` options; `queryParams`/`baseURL` settings; voice-family requirement error is `AIError.invalidArgument` (upstream plain `Error`, same message).

#### Files changed
- Packages/swift-ai-deepgram/Sources/SwiftAIDeepgram/DeepgramAudioModels.swift
- Packages/swift-ai-deepgram/Sources/SwiftAIDeepgram/DeepgramStreamingTranscriptionModel.swift
- Packages/swift-ai-deepgram/Tests/SwiftAIDeepgramTests/DeepgramProviderTests.swift (callbackMethod warning text)
- Packages/swift-ai-deepgram/Tests/SwiftAIDeepgramTests/DeepgramUpstreamParityTests.swift (new)
- Packages/swift-ai-deepgram/Porting/map.json (test registration)
- docs-site/scripts/provider-guides/deepgram.md (duration/usage wording)

#### Test results
`swift test --package-path Packages/swift-ai-deepgram --no-parallel`: 53 tests passed (32 before + 21 new). Docs-site check/build not run.


### @ai-sdk/cartesia (3.0.76) -> Packages/swift-ai-cartesia

Paths: `U/` = `scratchpad/upstream-all/pkg/cartesia/npm/src/`, `S/` = `Packages/swift-ai-cartesia/Sources/SwiftAICartesia/`.

#### Upstream test cases (64 `it`/`it.each` blocks)

| File | Total | Already translated | Newly translated | Still missing (reason) |
| --- | --- | --- | --- | --- |
| cartesia-speech-model.test.ts | 30 | 30 (CartesiaSpeechModelTests, Weekly20261108SpeechTests; aggregated) | 1 strengthened (sample-rate suffix parsed with JS `Number`) | 0 |
| cartesia-transcription-model.test.ts | 22 | 15 | 6 (fixture parse, dated `ink-whisper-*` routing, `ink-3`/`new-streaming-model` routed to streaming, PCM widening x3, thresholds sent in order, thresholds omitted with ordered warnings) | 1 platform-only: `----formdata-undici-` boundary regex (Swift uses its own multipart boundary). |
| cartesia-realtime-model.test.ts | 10 | 0 | 10 (all; new `CartesiaRealtimeModel`) | 0 (`turnDetection: null` expressed as `.disabled`, see #1) |
| cartesia-error.test.ts | 1 | 1 (structured error message tests) | 0 | 0 |
| lazy-schemas.test.ts | 1 | - | - | out-of-scope (zod lazy schemas) |

New/extended test files: `Tests/SwiftAICartesiaTests/CartesiaUpstreamParityTests.swift` (14 tests, new, registered in `Porting/map.json`); 4 tests appended to `CartesiaStreamingTranscriptionModelTests.swift` (reuse its private socket helpers).

#### Divergences

| # | Upstream evidence | Swift evidence (after fix) | Verdict | User-visible effect |
| --- | --- | --- | --- | --- |
| 1 | U/cartesia-provider.ts:51-54,124-151 `experimental_realtime` + U/cartesia-realtime-model.ts (whole file) | Missing before; now S/CartesiaRealtimeModel.swift (new) + `CartesiaProvider.realtimeModel/realtime/experimentalRealtime` (S/CartesiaProvider.swift) | fixed (new component) | Realtime Ink STT now available via `AIRealtimeSession`: `/access-token` client secret (`expires_in`, 1-3600 s, English only), turn/manual endpoints, `access_token` query, binary audio, `finalize` commit, Ink 2 event normalization incl. manual transcript assembly. Platform note: Swift `turnDetection` cannot distinguish `undefined` from `null`; nil keeps turn detection, `.disabled` selects manual finalize. Upstream `getToken` helper is covered by `realtimeModel(..).createClientSecret(...)`. Client-secret HTTP failure is `AIError.apiCall` with upstream message text (upstream plain `Error`). |
| 2 | U/cartesia-transcription-model.ts:223-245 timestampGranularities warning first, then thresholds in TURN_THRESHOLD_PARAMS order | S/CartesiaStreamingTranscriptionModel.swift:52-66 (was thresholds alphabetically, then timestamp) | fixed | Stream-start warning order matches. |
| 3 | U/cartesia-transcription-model.ts:580-587 threshold query params in declaration order | S/CartesiaStreamingTranscriptionModel.swift:183-188,349 (was alphabetical) | fixed | WebSocket URL parameter order matches. |
| 4 | U/cartesia-speech-model.ts:87-101 `Number(sampleRateText)` | S/CartesiaSpeechModel.swift:330,434 (was `Int(...)`) | fixed | `wav_16000.0` etc. accepted like upstream instead of warning. |
| 5 | U/cartesia-speech-model.ts:186-194 provider options parsed before the voice check | S/CartesiaSpeechModel.swift:19-26 | fixed | Invalid provider options are reported before a missing voice, as upstream. |
| 6 | U/cartesia-transcription-model.ts:84-138 batch body sends only `providerOptions.cartesia.language` (V4 call options have no `language`) | S/CartesiaTranscriptionModel.swift:29-30 falls back to `AudioTranscriptionRequest.language` | reported (undocumented Swift-only extension; not required by the platform; test `cartesiaBatchTranscriptionMapsGenericLanguage` asserts it). Deepgram ignores the same field "like upstream". | Swift callers setting `language` send a `language` form field that upstream would never send. Recommend documenting or removing in a deliberate change. |
| 7 | U/cartesia-transcription-model.ts:143-147,199-203 `UnsupportedFunctionalityError` ("non-streaming transcription with X" / "streaming transcription with X") | S/CartesiaTranscriptionModel.swift:21-26, S/CartesiaStreamingTranscriptionModel.swift:35-40 `AIError.invalidArgument` | reported (no core error type) | Error type/message differ; both reject before network. |
| 8 | Capability inventory | Umbrella `Sources/SwiftAISDK/Providers/ProviderCapabilityMatrix.swift:52` notes (generated from `Porting/packages.json`) do not mention realtime | reported (non-editable inputs) | Catalog/capability notes should add Cartesia realtime; package release metadata needs a minor bump for the new public API. |

Checked and matching: provider headers (`Authorization: Bearer`, `Cartesia-Version` default `2026-03-01`, user-agent `ai-sdk-cartesia/3.0.76`), speech body/output-format resolution, locale/language precedence and conflict, speed/volume/emotion generation_config, error schema (`title: message`, `doc_url` optional non-null), batch multipart fields and file name, Ink 2 streaming endpoint/token/keyterms/encoding warnings/event mapping.

#### Files changed
- Packages/swift-ai-cartesia/Sources/SwiftAICartesia/CartesiaRealtimeModel.swift (new)
- Packages/swift-ai-cartesia/Sources/SwiftAICartesia/CartesiaProvider.swift (additive factory methods)
- Packages/swift-ai-cartesia/Sources/SwiftAICartesia/CartesiaSpeechModel.swift
- Packages/swift-ai-cartesia/Sources/SwiftAICartesia/CartesiaStreamingTranscriptionModel.swift
- Packages/swift-ai-cartesia/Tests/SwiftAICartesiaTests/CartesiaUpstreamParityTests.swift (new)
- Packages/swift-ai-cartesia/Tests/SwiftAICartesiaTests/CartesiaStreamingTranscriptionModelTests.swift (4 appended tests)
- Packages/swift-ai-cartesia/Porting/map.json (source + test registration)
- docs-site/scripts/provider-guides/cartesia.md (new "Realtime transcription (Ink)" section)

#### Test results
`swift test --package-path Packages/swift-ai-cartesia --no-parallel`: 50 tests passed (32 before + 18 new). Docs-site check/build not run.


## Audio group: Hume, LMNT, Voyage, TypeSafe AI, Gladia, AssemblyAI, Fish Audio, MiniMax

Upstream paths below are relative to `scratchpad/upstream-all/pkg/<slug>/repo-src/` (identical to `npm/src` for these packages). Swift paths are relative to the repo root.

### @ai-sdk/hume → Packages/swift-ai-hume

Upstream test cases: 10 (hume-speech-model.test.ts 8, hume-error.test.ts 1, lazy-schemas 1).
- Already translated (partially): 5. Newly translated: 9 in `HumeUpstreamParityTests.swift` (all 8 speech cases + error fixture).
- Still missing: lazy-schemas (JS-only lazy zod init); `currentDate` injection (Swift cannot inject the clock; test asserts a fresh timestamp instead).

Divergences:
1. Settings header `X-Hume-Api-Key` did not reliably override the key. Upstream `hume-provider.ts` spreads `...options.headers` after `X-Hume-Api-Key`; Swift lower-cased settings headers, then inserted mixed-case `X-Hume-Api-Key`, and `withUserAgentSuffix` re-normalized two colliding keys (nondeterministic winner). Swift `HumeProvider.swift:41`. **Fixed.**
2. Empty `outputFormat` (`""`) produced an "Unsupported output format" warning; upstream guards with `if (outputFormat)` (`hume-speech-model.ts` getArgs). Swift `HumeAudioModels.swift:197`. **Fixed.**
- Platform-only: errors map to `AIError.apiCall` with `body` = upstream message via the shared `audioProviderHTTPStatusError` (see cross-package report).

### @ai-sdk/lmnt → Packages/swift-ai-lmnt (no upstream tests; compared with source)

Upstream test cases: 0. New source-derived tests: 5 in `LMNTSourceParityTests.swift` (default body/voice `ava`/`mp3`, empty language, empty format, provider-option defaults overriding call speed, header override).

Divergences:
1. Empty `language` sent as `"language": ""`; upstream `if (language)` omits it (`lmnt-speech-model.ts:110`). Swift `LMNTAudioModels.swift:32`. **Fixed.**
2. Empty `outputFormat` warned; upstream `if (outputFormat)` skips (`lmnt-speech-model.ts:75`). Swift `LMNTAudioModels.swift:175`. **Fixed.**
3. Settings `X-Api-Key` (any case) collided with the generated `x-api-key` (settings headers were not lower-cased first). Upstream spreads settings headers last (`lmnt-provider.ts` getHeaders). Swift `LMNTProvider.swift:31`. **Fixed.**
- Verified matching: zod defaults (`sampleRate 24000, speed 1, conversational false, topP 1, temperature 1`) are applied whenever `providerOptions.lmnt` is present and override the call speed (upstream behavior, now pinned by a test).

### @ai-sdk/voyage → Packages/swift-ai-voyage

Upstream test cases: 23 (embedding 8 incl. 4-row it.each, reranking 10, provider 4, lazy 1).
- Already translated: ~6 (scenario-level, without fixtures). Newly translated: 22 in `VoyageUpstreamParityTests.swift` (fixtures copied verbatim inline), plus 2 extra.
- Still missing: lazy-schemas (JS-only); exact `content-length` header snapshot (test-server artifact).

Divergences:
1. Error message: upstream `voyageFailedResponseHandler` uses `{detail}` as the message (`voyage-error.ts:19-22`); Swift used the raw body. Now `AIAPICallError.message = detail`, raw body kept in `responseBody`. Swift `VoyageProvider.swift:90`. **Fixed.**
2. Object documents for rerank were stringified with Foundation's default `\/` slash escaping; upstream `JSON.stringify` never escapes `/` (`reranking/voyage-reranking-model.ts:67-70`). Documents containing URLs were sent with different text. Swift `VoyageModels.swift:273` now uses `decisionJSONText` (sorted keys, no slash escaping). **Fixed.**
- Platform-only: object key order is sorted (Swift dictionaries have no insertion order).
- Note (not changed): Swift `responseMetadata` adds `modelID`/`timestamp` that upstream embedding/rerank responses do not expose (additive).

### @ai-sdk/typesafe-ai → Packages/swift-ai-typesafe-ai

Upstream test cases: 56 declarations (decision-model 48, provider 7, lazy 1), ~95 expanded rows.
- Already translated: ~22. Newly translated: ~45 declarations in `TypeSafeAIUpstreamParityTests.swift` (fixtures `decision-request.json`/`decision-response.json` copied inline).
- Still missing: lazy-schemas (JS-only); workflow serialize/deserialize (2, JS-only); import-time default provider from env (Swift global is a `let`); `forwards null boolean criteria` and `{instructions: null}` box variant (core `AIEvaluationQuestion` cannot distinguish absent from null; see reported); `criteria: [undefined]` (not representable in Swift); "text" file data variant (not in Swift enum).

Divergences:
1. Text-only requests sent `"assets": null` (JSONValue nil literal = `.null`); upstream omits `assets` unless images exist (`typesafe-ai-decision-model.ts:233-247`). Swift `TypesafeAIDecisionModel.swift:73`. **Fixed.**
2. Questions without instructions sent `"instructions": null`; upstream spreads the question so absent instructions are omitted (`:237-246`). Swift `TypesafeAIDecisionModel.swift:192` now omits `.null`. **Fixed** (explicit-null cannot be expressed; reported).
3. Warning order: Swift put `maxOutputTokens`/`reasoning` before provider-option warnings; upstream pushes provider-option warnings first (`:120-133`). Swift `:65-66`. **Fixed.**
4. HTTP errors put the envelope message into `responseBody` and dropped the raw body; upstream `createJsonErrorResponseHandler` sets `message` and keeps `responseBody` raw (`typesafe-ai-decision-api.ts:58-76`). Swift `:376`. **Fixed.**
5. Malformed successful responses reported custom text in `responseBody`; upstream `createJsonResponseHandler` throws APICallError `message: 'Invalid JSON response'` with raw body. Swift `:419`. **Fixed.**
6. `TYPESAFE_AI_BASE_URL` was ignored; upstream `loadOptionalSetting` (`typesafe-ai-provider.ts`). Swift `TypesafeAIProvider.swift:53-57` (respects `settings.environment` override). **Fixed.**
7. `evaluationModel` reported provider `typesafe.evaluation`; upstream `evaluationModel === decisionModel`, provider `typesafe.decision`. Swift `TypesafeAIProvider.swift:52`. **Fixed** (two existing assertions updated).
8. URL/reference file data: wrong error text and checked after media type; upstream checks data type first with `TypeSafe AI decision file input: <mediaType> (<data.type>)` (`:150-159`). Swift `TypesafeAIDecisionOptions.swift:65`. **Fixed.**
- Platform-only: JSON state text uses sorted keys (`finds references in nested JSON…` asserts the sorted form); generated references are UUIDs instead of `generateId()`.
- Docs: `docs-site/scripts/provider-guides/typesafe.md` documents the base URL env var and error mapping.

### @ai-sdk/gladia → Packages/swift-ai-gladia

Upstream test cases: 55 declarations (transcription-model 41, options-resolution 12, error 1, lazy 1).
- Already translated: ~22 (scenario-level). Newly translated: ~35 rows in `GladiaUpstreamParityTests.swift` with verbatim fixtures in `GladiaUpstreamFixtures.swift`.
- Still missing: options-resolution unit tests (12; internal helpers, covered through request-level tests); fake-clock timeout tests (2, `Date.now` mocking — existing Swift timeout test uses real time); workflow serialization (2, JS-only); lazy (JS-only); audio-intelligence passthrough cases (3; covered by raw `providerMetadata.gladia == fixture`).

Divergences:
1. Utterances with empty text were dropped from `segments` (shared `transcriptionSegments` filters empty text); upstream maps every utterance (`gladia-transcription-model.ts:453-459`). Swift `GladiaTranscriptionParsing.swift:8`. **Fixed.**
2. `responseMetadata.id` was the Gladia job ID (from `aiResponseMetadata(from: raw)`); upstream response has only timestamp/modelId/headers (`:460-464`). Swift `GladiaAudioModels.swift:100`. **Fixed.**
- Platform/mapping: job failure and polling timeout map to `AIError.invalidResponse` with upstream messages (AISDKError names not representable).

### @ai-sdk/assemblyai → Packages/swift-ai-assemblyai

Upstream test cases: 31 (transcription-model 21, error 9, lazy 1).
- Already translated: ~19. Newly translated: 12 in `AssemblyAIUpstreamParityTests.swift`.
- Still missing: status-text fallbacks (2; Swift transport has no `statusText`, falls back to body text); `error.data` schema-stripping assertions (4; Swift error has no `data`); `currentDate` injection; lazy.

Divergences:
1. Words with empty text were dropped from `segments`; upstream maps all words (`assemblyai-transcription-model.ts:425-430`). Swift `AssemblyAITranscriptionParsing.swift:15`. **Fixed.**
2. Duration fallback used the max segment end; upstream uses the last word's end (`:419,432-434`). Swift `AssemblyAIAudioModels.swift:78`. **Fixed.**
3. `responseMetadata.id` was the transcript ID; upstream omits it (`:441-446`). Swift `:82`. **Fixed.**
4. Polling gives up after 60 s (Swift `AssemblyAIAudioModels.swift:101`, documented in `docs-site/scripts/provider-guides/assemblyai.md:18-19`); upstream polls with no timeout (`:280-330`). Long recordings fail in Swift. Documented but not platform-required. **Reported.**
5. The shared `AudioTranscriptionRequest.language` is sent as `language_code` (Swift `:43`, documented in guide line 55); upstream transcription calls have no language argument. **Reported** (documented-intentional).

### @ai-sdk/fish-audio → Packages/swift-ai-fish-audio

Upstream test cases: 47 (speech 20, transcription 17, provider 7, error 2, lazy 1).
- Already translated: ~42 across `FishAudioSpeechModelTests`, `FishAudioTranscriptionModelTests`, `FishAudioProviderTests`. Newly translated: 0.
- Still missing: base64-string audio input (Swift API takes `Data`); lazy; `currentDate`.
- Divergences: none found (format normalization/warnings, prosody, model header, normalizeLoudness s1 policy, `ignore_timestamps=false` default, `language_code` vs display language, error schema all match). No changes.

### @ai-sdk/minimax → Packages/swift-ai-minimax

Upstream test cases: 180 (video 111, chat 44, provider 18, image 6, lazy 1).
- Already translated: ~110 (chat/provider thoroughly; video warning texts largely untested). Newly translated: 6 image cases (`MiniMaxImageUpstreamParityTests.swift`) and 15 video warning/body cases (`MiniMaxVideoWarningParityTests.swift`).
- Still missing: remaining video rows that exercise operation start/status (`doStart`/`doStatus` webhook flows) and fake-clock polling; workflow serialization; lazy. Video source was compared line by line (warnings, resolution mapping, JS `Math.round` emulation, minimum durations) and matches.

Divergences:
1. Image API errors did not surface `error.message`; upstream `minimaxImageFailedResponseHandler` (`minimax-image-model.ts` end). Swift `MiniMaxHTTPConfiguration.swift:19` now sets `message` and keeps the raw body (Messages requests keep the Anthropic error policy; video keeps its own handler). **Fixed.**
- Chat model is the Anthropic package model with a MiniMax request policy; no cross-package divergence found in the paths checked.

### Umbrella (read-only)

`Sources/SwiftAISDK/Providers/{Hume,LMNT,Voyage,TypeSafeAI,Gladia,AssemblyAI,FishAudio}Compatibility.swift` and `OpenAICompatibleProvider.swift` route to the package models, so all fixes above apply to `AIProviders.hume/lmnt/voyage/gladia/assemblyAI(settings:)`. User-agent versions match the lock. One umbrella-only gap: `OpenAICompatibleProvider` for `hume` registers the auth header as `X-Hume-Api-Key` via `.apiKeyHeader(name:)`; header override precedence there was not tested (not changed).

### Cross-package items (reported, not fixed)

- Core `transcriptionSegments(from:)` (`Packages/swift-ai-core/Sources/SwiftAIProviderUtilities/TranscriptionParsing.swift:6-13`) drops empty-text items and defaults missing timings; upstream providers map every item. Fixed locally for Gladia/AssemblyAI; other users of the helper may diverge.
- Core `audioProviderHTTPStatusError` (`AudioResponseUtilities.swift:6`) puts the extracted message into `responseBody` and discards the raw body; upstream keeps both (`message` + raw `responseBody`). Affects Hume, LMNT, Gladia (and others).
- `Packages/swift-ai-cohere` `cohereJSONString` uses default `JSONEncoder` (escapes `/`) for object rerank documents, like the Voyage bug fixed here.
- Core `AIEvaluationQuestion` uses `instructions: JSONValue = .null` and `criteria: [String: JSONValue]?`, so "absent" vs explicit `null` cannot be expressed (TypeSafe `{instructions: null}` box and `criteria: null` boolean cases).

### Files changed (this part)

- Hume: `Sources/SwiftAIHume/HumeProvider.swift`, `HumeAudioModels.swift`; new `Tests/.../HumeUpstreamParityTests.swift`; `Porting/map.json`.
- LMNT: `LMNTProvider.swift`, `LMNTAudioModels.swift`; new `LMNTSourceParityTests.swift`; `Porting/map.json`.
- Voyage: `VoyageProvider.swift`, `VoyageModels.swift`; new `VoyageUpstreamParityTests.swift`; `Porting/map.json`.
- TypeSafe AI: `TypesafeAIDecisionModel.swift`, `TypesafeAIDecisionOptions.swift`, `TypesafeAIProvider.swift`; updated `TypesafeAIProviderTests.swift`, `Weekly20261108DecisionTests.swift`; new `TypeSafeAIUpstreamParityTests.swift`; `Porting/map.json`; `docs-site/scripts/provider-guides/typesafe.md`.
- Gladia: `GladiaAudioModels.swift`, `GladiaTranscriptionParsing.swift`; new `GladiaUpstreamParityTests.swift`, `GladiaUpstreamFixtures.swift`; `Porting/map.json`.
- AssemblyAI: `AssemblyAIAudioModels.swift`, `AssemblyAITranscriptionParsing.swift`; new `AssemblyAIUpstreamParityTests.swift`; `Porting/map.json`.
- MiniMax: `MiniMaxHTTPConfiguration.swift`; new `MiniMaxImageUpstreamParityTests.swift`, `MiniMaxVideoWarningParityTests.swift`; `Porting/map.json`.

### Test results (`swift test --package-path Packages/<pkg> --no-parallel`, all passing)

hume 24, lmnt 18, voyage 31, typesafe-ai 55, gladia 54, assemblyai 29, fish-audio 17, minimax 70 (Swift Testing counts; parameterized tests count once). Docs-site check/build not run.


### Final re-run of every audio package (group agent)

hume 24, lmnt 18, voyage 31, typesafe-ai 55, gladia 54, assemblyai 29, fish-audio 17, minimax 70, elevenlabs 99, deepgram 53, cartesia 50: all passing.

## Image and video providers

## Parity audit — group `media`

Scope: fal, luma, replicate, black-forest-labs, bytedance, klingai, heygen, quiverai, topaz,
tencent, parallel, scaledown, open-responses. Upstream = `scratchpad/upstream-all/pkg/<slug>`.

Method and limits: this was done by one agent; sub-agent fan-out was refused (concurrency limit).
Every package's main request/response/warning/error paths were compared with upstream `src`/`dist`.
fal, replicate, bytedance and topaz got a full line-by-line review. BFL, KlingAI, Tencent, HeyGen and
QuiverAI got a targeted review: model-API/endpoint selection, auth, status mapping and every
upstream warning/error string. Parallel/ScaleDown were fully compared. Open Responses was
black-box tested against upstream snapshots. Swift `@Test` counts include parameterized tests, so
the test counts below are scenario estimates, not a 1:1 ledger.

### Fixed divergences

| # | Package | Upstream evidence | Swift evidence (before) | User-visible effect |
|---|---|---|---|---|
| F1 | fal image | `fal-image-model.ts` doGenerate `providerMetadata` (only `content_type/file_name/file_data/file_size` renamed per image; rest of top level verbatim; `image` kept; empty image entries kept) | `FalMediaModels.swift` `falMetadataKey` renamed top-level `num_inference_steps`→`numInferenceSteps`, `has_nsfw_concepts`→…, copied unknown per-image keys, dropped empty entries and `image` | `providerMetadata.fal` now matches upstream (`num_inference_steps`, `debug_latents` raw, `images` always present) |
| F2 | fal image | getArgs `num_images: n` (core always passes n≥1) | only sent when `count` set | body now always has `num_images` (default 1) |
| F3 | fal image errors | `falFailedResponseHandler` (`loc.join('.'): msg` / `message`) | generic body text | `AIAPICallError.message == "prompt: Invalid prompt"`, url included |
| F4 | fal video/queue/speech/transcription errors | `fal-error.ts` `error.message` | raw description | `.failed(message:)` is now `"Internal server error"` (was `"fal.video request failed with HTTP 500: {...}"`) |
| F5 | fal video metadata | `buildResult` fixed shape `{videos:[{url,width,height,duration,fps,contentType}], seed, timings, has_nsfw_concepts, prompt}` | copied every key, renamed `has_nsfw_concepts`, included extra video keys | exact upstream metadata |
| F6 | fal transcription | segments keep every chunk, `endSecond` default 0, duration = last chunk `timestamp[1]`, language only from `inferred_languages`; timeout text | dropped empty chunks, end defaulted to start, used `duration`/`language` fields | segments/duration/language as upstream; timeout message "Transcription request timed out after 60 seconds" |
| F7 | fal speech | `fal-speech-model.ts` posts to `https://fal.run/${modelId}` (ignores baseURL) | used configured baseURL + queryParams | custom `baseURL` no longer redirects speech |
| F8 | replicate image | `input.num_outputs: n` always | only with `count` | body always has `num_outputs` (default 1) |
| F9 | replicate video | `doStart` sends **no** `prefer` header (test "should NOT send prefer header") | sent `prefer: wait[=N]` | header removed |
| F10 | replicate video | `doStart/doStatus/handleWebhookOption`; webhook → `webhook` + `webhook_events_filter:["completed"]`; failed/canceled → error status | not `AsyncVideoModel`; facade `poll`/`webhook` options unavailable | `ReplicateVideoModel` now conforms to `AsyncVideoModel` (additive) with upstream operation `{getUrl}` |
| F11 | bytedance | dist 2.0.86 exports `ByteDanceImageModel` (Seedream, `/images/generations`, `response_format:b64_json`, option mapping, warnings, usage) | provider threw `unsupportedModel(.image)` | new `ByteDanceImageModel`; `ByteDanceProvider.imageModel` works; capabilities `[.image,.video]` |
| F12 | bytedance video | `resolveReferenceContent`: inputReferences routed by media type (`video_url`/`reference_video`), warning for URL refs without mediaType, inputReferences replace provider `referenceImages`/`referenceVideos`, frame images suppress all refs, start image becomes `reference_image` when any ref exists | all inputReferences sent as images; provider `referenceVideos` still sent with inputReferences/frames; no warning | request content now matches upstream |
| F13 | bytedance | provider headers have no user-agent suffix | `ai-sdk/bytedance/2.0.71` (stale) | suffix removed (transport default `SwiftAISDK/bytedance` remains); header keys normalized |
| F14 | bytedance video (unary) | status error text `Video generation failed. Task ID: X. <detail>` | `Video generation failed: <json>` | unary failure message aligned with status path |
| F15 | black-forest-labs image | FLUX 3 `seed` and `blackForestLabs.<key>` warnings have no details | extra `message` text | warning content matches |
| F16 | topaz image/video | upstream warning `details` texts (prompt, aspectRatio, mask, n, files, duration, generateAudio, frameImages, inputReferences) and timeout text | paraphrased texts | warning/timeout messages identical |

### Reported, not fixed

- R1 (core, cross-package) `SwiftAI.generateImage` has no `n`/`maxImagesPerCall` batching.
  Upstream core splits n into ceil(n / maxImagesPerCall) parallel calls. Evidence:
  `swift-ai-core/Sources/SwiftAI/AIFacadeMedia.swift:181-230` calls `model.generateImage` once, and
  the `ImageModel` protocol has no `maxImagesPerCall`. Effect: Luma, BFL, Topaz and ByteDance image
  ignore `count > 1` and return 1 image where upstream returns n. fal and replicate forward
  `count` in one request.
- R2 (umbrella, `Sources/SwiftAISDK`) `ProviderRegistry.byteDance` declares
  `supportedCapabilities: [.video]`, and `OpenAICompatibleProvider.imageModel` has no
  `bytedance` route, so Seedream is unavailable from the umbrella. `buildHeaders` still adds
  `ai-sdk/bytedance/2.0.71`, which upstream 2.0.86 does not send.
- R3 (umbrella) Stale user-agent versions: `ProviderRegistry.swift:396` heygen `3.0.14`
  (native/npm `3.0.25`), `:427` topaz `3.0.24` (`3.0.28`), `:337` open-responses `2.0.82` (`2.0.87`).
  Root `Tests/SwiftAISDKTests/ResponsesEndpointTests.swift:413` pins the stale value.
- R4 Documented local extensions that the platform does not require (not changed):
  - Replicate video maps `providerOptions.resolution` to `size` and converts the `image`/`imageUrl`
    options; upstream passes these keys raw.
  - Replicate, fal and ByteDance unary video honor `pollIntervalMs`/`pollTimeoutMs`. Upstream fal
    passes unknown keys (including these) raw, and ByteDance ignores them with a deprecation warning.
  - fal video maps `imageUrl`→`image_url`.
  - fal transcription strips a `fal-ai/` prefix from the model ID and adds the call-level `language`.
- R5 Open Responses extension codecs (`open-responses-extension.ts`, registered hosted-tool and bare
  items) are absent. This gap is already listed in `Docs/PortingStatus.md`. The language model
  lives in `swift-ai-openai`, which is outside this group.
- R6 Minor, not fixed:
  - KlingAI JWT JSON key order may differ (the token is semantically identical).
  - Topaz/Luma invalid-argument texts name Swift parameters (`files`, `inputReferences`).
  - fal video `doStart` returns submit headers where upstream returns none.
  - ByteDance status GET omits the `Content-Type` header that upstream sends.

### Per package

**fal**: 71 upstream cases, about 30 previously translated, 13 new tests in
`FalUpstreamParityTests.swift`. They cover lora/lcm metadata, null file fields, empty timings, null
width/height, single-image response, the API error, the aspect-ratio body, video status metadata and
error status, the resource-exhausted error and transcription chunks; one more test covers the
speech URL. Still missing: workflow serialization and lazy-schema tests (platform-only), capability
`it.each`, and some option permutations (behavior is already covered by existing tests). Fixes
F1–F7.

**luma**: 32 upstream, about 15 translated. No divergence found. Missing: path-segment encoding,
header pass-through, the 5 response-schema cases and the >4-images error. These are low risk
because the code matches.

**replicate**: 78 upstream, about 35 translated, 10 new in
`ReplicateVideoOperationUpstreamTests.swift` (start, versioned URL, no prefer, webhook,
completed/pending/failed/canceled/no-output, image n default). Fixes F8–F10. Missing: Flux-2
`maxImagesPerCall` (R1) and the remaining video option permutations.

**black-forest-labs**: 152 upstream, about 40 scenario-level Swift tests. Model API selection,
FLUX 3 aspect/size warnings, video draft-enhance, keyframe and reference warnings were spot-checked
and match. F15 fixed. Many permutations are still untranslated (time limit).

**bytedance**: 93 upstream, about 30 translated, 18 new in
`ByteDanceImageAndReferenceUpstreamTests.swift` (all image cases, input-reference routing and
warning, suppression, webhook raw/explicit `it.each`). Fixes F11–F14.

**klingai**: 111 upstream. Auth resolution order, JWT claims, endpoint map, mi2v switch, status
messages and warnings match. No fix needed. Many permutations remain untranslated.

**heygen**: 46 upstream, already well covered (59 Swift tests). Warning texts match. No divergence
found.

**quiverai**: 70 upstream. Operation paths and warning texts match. No divergence found in the
reviewed paths; the language model was not deep-diffed.

**topaz**: 83 upstream, about 35 Swift tests. F16 fixed; R6 error texts left as they are.

**tencent**: 55 upstream. TokenHub/VOD status and error texts, metadata shapes and model routing
match. No divergence found.

**parallel**: 14 upstream, 13 translated; workflow serialization is platform-only. No divergence.

**scaledown**: 18 upstream, 18 translated. No divergence.

**open-responses**: 129 upstream, 14 previously, 7 new black-box tests in
`OpenResponsesLanguageModelRequestUpstreamTests.swift` (basic body, request-parameters snapshot,
top-level reasoning ×5, no reasoning, system instructions, unsupported warnings). All pass, so no
divergence was found in those paths. Extension tests are missing (R5).

### Files changed

- fal: `Sources/SwiftAIFal/FalMediaModels.swift`, `FalAudioModels.swift`,
  `Tests/.../FalProviderTests.swift` (expectation updated to upstream key), new
  `Tests/.../FalUpstreamParityTests.swift`, `Porting/map.json`.
- replicate: `Sources/SwiftAIReplicate/ReplicateMediaModels.swift`, `Tests/.../ReplicateProviderTests.swift`,
  new `Tests/.../ReplicateVideoOperationUpstreamTests.swift`, `Porting/map.json`,
  `docs-site/scripts/provider-guides/replicate.md`.
- bytedance: `Sources/SwiftAIByteDance/ByteDanceMediaModels.swift`, `ByteDanceProvider.swift`, new
  `ByteDanceImageModel.swift`, `Tests/.../ByteDanceProviderTests.swift`, new
  `Tests/.../ByteDanceImageAndReferenceUpstreamTests.swift`, `Porting/map.json`,
  `docs-site/scripts/provider-guides/bytedance.md`.
- black-forest-labs: `Sources/SwiftAIBlackForestLabs/BlackForestLabsMediaModels.swift`.
- topaz: `Sources/SwiftAITopaz/TopazImageModel.swift`, `TopazVideoModel.swift`.
- open-responses: new `Tests/.../OpenResponsesLanguageModelRequestUpstreamTests.swift`, `Porting/map.json`.

### Test results (`swift test --package-path Packages/<pkg> --no-parallel`)

| package | result |
|---|---|
| swift-ai-fal | 35 tests passed |
| swift-ai-replicate | 37 tests passed |
| swift-ai-bytedance | 42 tests passed |
| swift-ai-black-forest-labs | 38 tests passed |
| swift-ai-topaz | 35 tests passed |
| swift-ai-open-responses | 20 tests passed |

Not run: `node Scripts/test-packages.mjs`, the root compatibility suite and the docs-site build.

