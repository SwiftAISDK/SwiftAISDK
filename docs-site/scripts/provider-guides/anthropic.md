## Haiku 5.5, decisions, and stream metadata

Haiku 5.5 supports adaptive thinking, xhigh effort and a 128k maximum output. Budget thinking is converted to adaptive with a compatibility warning; sampling is rejected. Explicit disabled thinking remains valid at supported effort levels. Unsupported models no longer warn for an explicit `strict: false` tool.

Streaming consumers can inspect `.custom(kind: "anthropic.message_start", ...)` for initial provider usage and response identity. Replaying `anthropic.fallback` adds the required server-side fallback beta. `decisionModel(...)` uses the native structured-output adapter; see [Decision](../../core/decide/).

Set `ProviderSettings.batchResultDownloads` to bound downloaded JSONL rows. Unicode custom header values remain on Anthropic AWS/Bedrock requests but are excluded from canonical signed headers.

Batch `providerOptions.anthropic.anthropicBeta` must be an array of strings. Omit it when no beta is needed; explicit null, a single string, or mixed-type arrays fail before network I/O. Cache control shares its four-breakpoint limit across prompt blocks and tool definitions. A part's cache marker takes precedence over a message marker on the same block and counts only once.

## Citations and tool transcripts

Generated text and streamed text-end parts expose normalized `AICitation` values for document pages, character ranges, content blocks, web-search results, and search-result locations. Read `TextGenerationResult.citations` for all cited text blocks. The complete original citation objects remain in the text part's provider metadata; document offsets describe the source document and do not become generated-text offsets. Batch results use available citation titles and file IDs with a plain-text document fallback because original prompt documents are unavailable.

Retrieved web-search results remain standalone sources. Citations do not add duplicate sources when search results are present; citation-only responses still expose fallback sources, emitted before the stream finishes.

`toolChoice: ["type": "none"]` keeps tool definitions in the request. Manual `thinking: enabled` changes required or named tool choices to automatic with a warning; a named choice retains only its selected tool. Adaptive or disabled thinking retains supported forced choices. Tool transcripts can replay provider-referenced files in tool results and JSON/error-JSON tool-search failures.
## Incomplete streams and the native response boundary

Nonempty text, reasoning or tool input that ends before the provider's
`message_stop` finishes as `interrupted`; partial content remains available.
An explicit stop retains its mapped finish reason. The native API ends one
logical response and cancels its HTTP body at the first `message_stop`, even
if the server leaves the body open. Unlike the JavaScript codec, it does not
consume additional Messages responses from the same body. A multi-message
session would require a separate explicit lifecycle contract.

## Refreshable authentication and JSON fallback

`AnthropicProviderSettings.authTokenProvider` accepts an asynchronous throwing closure, resolved before each Messages, Batch, Files or Skills HTTP request. Model construction does not call it; supplier errors propagate before network I/O. The supplier takes precedence over `authToken`, and bearer authentication conflicts with an explicitly supplied API key. Authentication does not automatically add an OAuth beta. Existing static API keys and bearer tokens continue to work.

When a hosting adapter disables native structured output but the model rejects forced tool use, Sonnet 5.5, Opus 5.5 and Fable 5.1 use native JSON output only when the schema can be represented without loss. Recursive references, open maps and schemas with more than ten optional properties keep the JSON response tool with automatic tool choice. Definitions next to a top-level `$ref` are preserved. Required properties do not count toward the optional-property limit; referenced definitions count at every use.

If the model answers directly instead of calling the JSON response tool, generation returns its final text. Streaming holds that text until the response ends, preserves its citations, and discards preamble before tool activity. A JSON-tool call replaces held text; a tool or pause handoff does not expose preamble as the JSON answer. The existing one-response native boundary still applies. Portable `xhigh` reasoning rounds down to `high` on models without `xhigh`; Sonnet 5.5 reports a compatibility warning when `none` selects its lowest `between_tools` mode.
