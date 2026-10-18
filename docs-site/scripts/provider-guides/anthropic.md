## Haiku 5.5, decisions, and stream metadata

Haiku 5.5 supports adaptive thinking, xhigh effort and a 128k maximum output. Budget thinking is converted to adaptive with a compatibility warning; sampling is rejected. Explicit disabled thinking remains valid at supported effort levels. Unsupported models no longer warn for an explicit `strict: false` tool.

Streaming consumers can inspect `.custom(kind: "anthropic.message_start", ...)` for initial provider usage and response identity. Replaying `anthropic.fallback` adds the required server-side fallback beta. `decisionModel(...)` uses the native structured-output adapter; see [Decision](../../core/decide/).

Set `ProviderSettings.batchResultDownloads` to bound downloaded JSONL rows. Unicode custom header values remain on Anthropic AWS/Bedrock requests but are excluded from canonical signed headers.

## Citations and tool transcripts

Generated text and streamed text-end parts expose normalized `AICitation` values for document pages, character ranges, content blocks, web-search results, and search-result locations. Read `TextGenerationResult.citations` for all cited text blocks. The complete original citation objects remain in the text part's provider metadata; document offsets describe the source document and do not become generated-text offsets. Batch results use available citation titles and file IDs with a plain-text document fallback because original prompt documents are unavailable.

Retrieved web-search results remain standalone sources. Citations do not add duplicate sources when search results are present; citation-only responses still expose fallback sources, emitted before the stream finishes.

`toolChoice: ["type": "none"]` keeps tool definitions in the request. Manual `thinking: enabled` changes required or named tool choices to automatic with a warning; a named choice retains only its selected tool. Adaptive or disabled thinking retains supported forced choices. Tool transcripts can replay provider-referenced files in tool results and JSON/error-JSON tool-search failures.
