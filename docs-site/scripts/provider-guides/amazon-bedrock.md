## Reasoning, dimensions, and Haiku 5.5

Explicit disabled reasoning removes unused effort and budget fields. Explicit provider effort/budget overrides portable defaults; type/display-only settings still derive missing values. Portable `max` remains max for supported families and maps to high with a warning for Nova 2.

Titan, Cohere and Nova embeddings accept top-level dimensions unless the provider-specific dimensions override them. Haiku 5.5 uses the JSON tool fallback where Bedrock native structured output is unsupported; explicit `strict: false` does not warn. SigV4 excludes non-ASCII header values from signed headers while retaining outgoing values.

## Claude structured-output compatibility

Bedrock only sends strict tool definitions and native structured-output fields to recognized supported Claude generations. Unknown future Claude IDs and unrecognized minor versions use JSON instructions in automatic structured-output mode, retaining ordinary application tools without adding an incompatible synthetic response tool. Explicit `jsonTool` selection keeps its existing model-specific behavior.

Claude Sonnet 4.6 and Haiku 4.5 retain strict tools but use the JSON-tool fallback for unreliable native output. Non-Claude models and opaque inference-profile IDs keep their existing capability behavior. The Anthropic Messages adapter also inherits normalized citations, web-search source deduplication, manual-thinking tool-choice safeguards, and replayable file-reference/tool-search-error transcripts.

## Rotating bearer credentials and current thinking policies

`AmazonBedrockProviderSettings.apiKeyProvider` accepts an asynchronous throwing closure for short-lived bearer credentials. It is resolved before each Converse, invoke-model, embedding, image, reranking or Mantle HTTP request. Returned values are trimmed and must be non-empty; an invalid callback result fails before sending and does not fall back to SigV4. Static bearer keys and the existing AWS `credentialProvider` remain available.

Converse omits disabled thinking for Claude 3.5 and earlier, sends it for supported later models, and selects the lowest supported thinking mode with a warning when a model cannot disable thinking. Existing raw and typed effort settings survive that fallback; incompatible effort above `high` is lowered with a warning. Portable reasoning uses the closest supported effort, preferring a lower level. GPT-OSS accepts `low`/`medium`/`high`; other OpenAI-family efforts remain forward compatible.

Document names are unique across user messages and tool results in one request. Duplicate sanitized names receive deterministic ` (2)`, ` (3)` suffixes within Bedrock's 200-character limit, preserving prompt-cache stability. The Anthropic invoke adapter can use native JSON output for models that reject forced tools when the schema is representable; recursive or open schemas retain the JSON-tool fallback.
## Current Claude schemas and tools

Reviewed Claude 5/5.5 families support native schemas and strict tools where the
catalog declares support. Automatic selection requires schema preservation;
unknown future Claude aliases retain conservative handling. Explicit
`structuredOutputMode` continues to choose output-format or JSON-tool behavior.

Named choices on supported Anthropic models retain all function tools and disable
parallel use by default; `disableParallelToolUse: false` opts out. Other model
families receive only the selected tool. Image `seed: 0` is preserved, and empty
foreign assistant signature text is filtered before final prefill trimming.
