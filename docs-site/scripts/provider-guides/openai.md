## Decisions and current Responses behavior

Use `provider.decisionModel("gpt-6-luna")` with [`AI.experimentalDecide`](../../core/decide/). OpenAI Decisions send `/decisions`, named questions and inline image evidence; the experimental Evaluation entry points remain available through the same native implementation.

GPT-6-sol/luna sampling and logprobs follow the final effective reasoning effort, including configuration updates. Typed tool errors are wrapped as `{ "error": value }` in OpenAI requests. Failed/incomplete web-search results keep error/status metadata in generation, streaming and batch results. Stored assistant references retain structured-output schema breakpoints.

[`Batch downloads`](../../core/batch-text/) accept `ProviderSettings.batchResultDownloads` with a default 64 MiB UTF-8 row limit.

## Citation and history parity

Responses text content exposes `citations` independently of `result.sources`; streaming text-end parts carry the same citations. Citation sources use stable URL or file IDs and retain provider UTF-16 offsets. Retrieved web URLs and deduplicated file-search documents populate standalone sources, including uncited retrieved documents. Annotation sources remain a fallback when retrieval data is absent; `file_path` annotations remain standalone sources only.

For tools loaded during a conversation, attach `providerMetadata: ["openai": ["additionalTools": [...]]]` to an ordinary `AIToolResult`. Each strict function definition requires `type: "function"`, a nonempty `name`, and object `parameters`, with optional `description` and `strict`. The request inserts a developer `additional_tools` item immediately after that result. Set a function tool's `providerOptions.openai.omitFromRequestTools` to `true` to retain local execution and validation while omitting its top-level definition. Such tools cannot be forced or allow-listed until they are available through history.

Stored reasoning-model assistant text replays its content when the preceding reasoning was pruned. With `store: false`, provider-executed web-search results replay search/open-page/find-in-page actions. Custom tool streaming declares `inputEncoding: .text`. `webSearchPreview` is deprecated; use `webSearch`.
