## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.anthropic()
let model = try provider.languageModel("claude-sonnet-5-5")
let result = try await model.generateText("Summarize the Messages API in one sentence.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIAnthropic`, then call
`AIProviders.anthropic(configuration: AnthropicProviderSettings(...))`; the
configuration argument defaults to environment credentials.

`languageModel(...)` and `messages(...)` both return a Messages model that also
supports batches. The default base URL is `https://api.anthropic.com/v1`.

## Authentication

- **API key**: `apiKey`, or `ANTHROPIC_API_KEY`, sent as `x-api-key`.
- **Bearer token**: `authToken`, sent as `Authorization: Bearer ...`. Setting both
  `apiKey` and `authToken` throws. No OAuth beta header is added automatically.
- **Refreshing tokens**: `AnthropicProviderSettings.authTokenProvider` is an async
  throwing closure called before each Messages, Files, Skills and Batch request. It
  takes precedence over `authToken`; errors stop the request before it is sent.

```swift
import SwiftAI
import SwiftAIAnthropic

let provider = try AIProviders.anthropic(configuration: AnthropicProviderSettings(
    authTokenProvider: { try await tokenStore.currentToken() }
))
```

## Provider options

Pass options under `providerOptions["anthropic"]`. Invalid values throw before
any network request.

```swift
let result = try await model.generateText(
    "Prove that there are infinitely many primes.",
    options: LanguageGenerationOptions(
        maxOutputTokens: 16_000,
        providerOptions: [
            "anthropic": [
                "thinking": ["type": "enabled", "budgetTokens": 5_000],
                "effort": "high",
            ],
        ]
    )
)
print(result.reasoning)
```

Commonly used keys:

- `thinking`: `["type": "adaptive"]`, `["type": "enabled", "budgetTokens": N]` or
  `["type": "disabled"]`. Adaptive thinking also accepts `display`.
- `effort`: output effort such as `"low"`, `"medium"`, `"high"`, `"xhigh"`, `"max"`.
- `sendReasoning`: replay earlier reasoning (default `true`).
- `disableParallelToolUse`, `toolStreaming`, `structuredOutputMode`.
- `serviceTier`: `"auto"`, `"standard_only"`, `"standard"` or `"priority"`. The
  tier that was applied is returned in `providerMetadata["anthropic"]["serviceTier"]`.
- `cacheControl`, `metadata`, `mcpServers`, `container`, `speed`, `inferenceGeo`,
  `taskBudget`, `fallbacks`, `compaction`, `contextManagement`, `anthropicBeta`
  (an array of beta header strings).

Portable `reasoning` is mapped per model: adaptive-thinking models receive
adaptive thinking with summarized display, older models receive a token budget,
and `xhigh` is lowered to `high` on models that do not support it.

### Model-specific limits

The adapter knows the capabilities of current Claude families (Opus, Sonnet,
Haiku and Fable generations up to 5.5) and adjusts requests instead of failing:

- Models that reject sampling parameters drop `temperature`, `topP` and `topK`
  with a warning.
- Models that cannot disable thinking, or that reject budget thinking, switch to
  their closest supported mode with a compatibility warning. Incompatible
  `xhigh` or `max` effort is lowered to `high`.
- Manual (`enabled`) thinking turns a required or named tool choice into `auto`
  with a warning. `toolChoice` `none` keeps tool definitions in the request.

## Prompt caching

Mark a message or content part with `cacheControl` in its provider metadata:

```swift
let messages = [
    AIMessage(
        role: .system,
        content: [.text(longInstructions)],
        providerMetadata: ["anthropic": ["cacheControl": ["type": "ephemeral"]]]
    ),
    .user("Answer using the instructions above."),
]
let result = try await model.generateText(messages: messages)
```

Anthropic allows four cache breakpoints, shared across prompt blocks and tool
definitions. A part-level marker wins over a message-level marker on the same
block and is counted once.

## Provider tools

`AnthropicTools` builds Anthropic-hosted and client-executed tool definitions,
including `webSearch_20250305`, `webSearch_20260318`, `webFetch_20250910`,
`codeExecution_20250825`, `bash_20250124`, `textEditor_20250728`,
`computer_20251124`, `computerToolset_20260801`, `memory_20250818`,
`toolSearchRegex_20251119`, `toolSearchBm25_20251119` and `advisor_20260301`.

```swift
let result = try await model.generateText(
    "What changed in Swift concurrency this year?",
    tools: LanguageToolOptions(rawTools: [
        "web_search": AnthropicTools.webSearch_20250305(maxUses: 3),
    ])
)
print(result.sources)
```

Required beta headers are added automatically. Retrieved web-search results are
returned as sources without duplicates from citations. See [Tools](../../core/tools/).

## Structured output

`structuredOutputMode` chooses how JSON output is produced: `"outputFormat"`
(native JSON Schema output), `"jsonTool"` (a forced JSON response tool) or
`"auto"` (default). In automatic mode, native output is used only on supported
models and when the schema can be represented without loss; recursive schemas,
open maps and other unsupported shapes use the JSON tool. If the model answers in
text instead of calling the JSON tool, that text is returned as the answer. See
[Structured output](../../core/structured-output/).

## Citations

Text parts carry normalized `AICitation` values for document pages, character
ranges, content blocks, web-search results and search-result locations. Read
`result.citations` for all of them; the original citation objects stay in the
text part's provider metadata. Document offsets refer to the source document,
not the generated text.

## Message threads

Threads are opt-in through `providerOptions["anthropic"]["thread"]`:
`["type": "create"]` starts one and
`["type": "continue", "previousMessageId": "msg_..."]` sends only the new turns.
Continuations omit leading system instructions and tool definitions, so start a
new thread to change them, and pass the same `anthropicBeta` values on every turn.
Keep the full history locally so you can recover when a thread expires
(`thread_not_found`). Threads cannot be combined with batches or with compaction
and context edits other than `clear_thinking_20251015` with `keep: "all"`.

Mid-conversation system messages can carry `toolChanges` that add or remove
tools; changes on the initial system message are ignored with a warning.

## Streaming

- `includePings: true` emits keepalive `.ping` stream parts; it defaults to false
  and is never sent in the request body.
- A `.custom` part whose value has `"kind": "anthropic.message_start"` carries the
  initial usage, response ID and model in `providerMetadata["anthropic"]`.
- A stream that ends with content but without `message_stop` finishes as
  `interrupted`, with the partial content kept.
- One call reads exactly one Messages response and closes the HTTP body at the
  first `message_stop`.

## Files, skills and batches

- `provider.files()` uploads buffered `Data`, reads metadata, downloads and
  deletes files. Streaming uploads are not supported. See [Files](../../core/files/).
- `provider.skills()` manages Anthropic skills; required beta headers are added.
- `provider.experimentalBatch()` runs Message Batches. Set
  `batchResultDownloads` in the settings to bound the size of downloaded result
  lines (64 MiB by default). Completion webhooks are not supported. See
  [Batch text](../../core/batch-text/).

## Decisions, evaluations and extraction

`decisionModel(...)`, `evaluationModel(...)` and `extractionModel(...)` run over
Messages with structured output. Extraction splits more than 16 fields into
parallel requests. See [Decisions](../../core/decide/),
[Evaluate](../../core/evaluate/) and [Extract](../../core/extract/).

## Related providers

The same Messages adapter powers [Claude Platform on AWS](../anthropic-aws/),
[Amazon Bedrock (Anthropic models)](../amazon-bedrock-anthropic/) and
[Google Vertex AI (Anthropic models)](../googlevertex-anthropic/).
