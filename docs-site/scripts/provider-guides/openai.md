## Decisions and current Responses behavior

Use `provider.decisionModel("gpt-6-luna")` with [`AI.experimentalDecide`](../../core/decide/). OpenAI Decisions send `/decisions`, named questions and inline image evidence; the experimental Evaluation entry points remain available through the same native implementation. Choice, score and boolean questions can omit instructions. Boolean criteria still become predicate instructions. The native Decisions endpoint ignores `maxOutputTokens` and `reasoning`, reporting an unsupported warning for each supplied setting.

GPT-6-sol/luna sampling and logprobs follow the final effective reasoning effort, including configuration updates. Typed tool errors are wrapped as `{ "error": value }` in OpenAI requests. Failed/incomplete web-search results keep error/status metadata in generation, streaming and batch results. Stored assistant references retain structured-output schema breakpoints.

[`Batch downloads`](../../core/batch-text/) accept `ProviderSettings.batchResultDownloads` with a default 64 MiB UTF-8 row limit.

## Citation and history parity

Responses text content exposes `citations` independently of `result.sources`; streaming text-end parts carry the same citations. Citation sources use stable URL or file IDs and retain provider UTF-16 offsets. Retrieved web URLs and deduplicated file-search documents populate standalone sources, including uncited retrieved documents. Annotation sources remain a fallback when retrieval data is absent; `file_path` annotations remain standalone sources only.

For tools loaded during a conversation, attach `providerMetadata: ["openai": ["additionalTools": [...]]]` to an ordinary `AIToolResult`. Each strict function definition requires `type: "function"`, a nonempty `name`, and object `parameters`, with optional `description` and `strict`. The request inserts a developer `additional_tools` item immediately after that result. Set a function tool's `providerOptions.openai.omitFromRequestTools` to `true` to retain local execution and validation while omitting its top-level definition. Such tools cannot be forced or allow-listed until they are available through history.

Stored reasoning-model assistant text replays its content when the preceding reasoning was pruned. With `store: false`, provider-executed web-search results replay search/open-page/find-in-page actions. Custom tool streaming declares `inputEncoding: .text`. `webSearchPreview` is deprecated; use `webSearch`.

## Prompt cache prewarming and shell controls

Responses accepts `providerOptions.openai.promptCacheOptions` with `mode: "implicit"` or `"explicit"`, `ttl: "30m"` or `"12h"`, and optional `prewarm: true`. A prewarm response or stream may contain no text and zero output tokens. Cache-write totals remain available in `TokenUsage`; `rawValue.input_tokens_details.cache_write_tokens_details` preserves the 30-minute and 12-hour token breakdown. User text parts forward `providerMetadata.openai.promptCacheBreakpoint`, including `ttl: "12h"` with `mode: "explicit"`, to the corresponding input content entry.

Shell calls are marked `providerExecuted` for container environments and remain client calls for local execution. Shell tool-call input preserves `action.timeoutMs` and `action.maxOutputLength` when OpenAI supplies them. Shell results expose `maxOutputLength`; replaying assistant history with `store: false` or sending a tool result keeps that output limit. Null controls are omitted in generated and streamed tool input/results.

## Transcription languages

Transcription normalizes recognized English language names and lowercase two-letter codes. When `language` is absent or unrecognized, exactly one valid entry in the returned `languages` list supplies `result.language`; mixed-language responses leave it unset. `providerMetadata.openai.languages` preserves the detected list, including an empty list, alongside diarized `segments`. Unknown language names and locale strings such as `en-US` no longer appear as normalized language codes.
## Final-answer JSON and incomplete streams

For JSON Responses, the last message marked `final_answer` is exposed as
`TextGenerationResult.structuredOutputText` for structured parsing. Full `text`,
`content`, citations and message metadata still include draft messages. A missing
selection uses concatenated text; an empty selection stays explicit. Ordinary
text requests retain their existing full-content behavior.

Chat, Completion and Responses streams that end without a provider completion
signal finish as `interrupted`. Preserve the partial output and choose whether
to retry; tool execution and automatic continuation stop for that response.
