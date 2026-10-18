## Reasoning, dimensions, and Haiku 5.5

Explicit disabled reasoning removes unused effort and budget fields. Explicit provider effort/budget overrides portable defaults; type/display-only settings still derive missing values. Portable `max` remains max for supported families and maps to high with a warning for Nova 2.

Titan, Cohere and Nova embeddings accept top-level dimensions unless the provider-specific dimensions override them. Haiku 5.5 uses the JSON tool fallback where Bedrock native structured output is unsupported; explicit `strict: false` does not warn. SigV4 excludes non-ASCII header values from signed headers while retaining outgoing values.

## Claude structured-output compatibility

Bedrock only sends strict tool definitions and native structured-output fields to recognized supported Claude generations. Unknown future Claude IDs and unrecognized minor versions use JSON instructions in automatic structured-output mode, retaining ordinary application tools without adding an incompatible synthetic response tool. Explicit `jsonTool` selection keeps its existing model-specific behavior.

Claude Sonnet 4.6 and Haiku 4.5 retain strict tools but use the JSON-tool fallback for unreliable native output. Non-Claude models and opaque inference-profile IDs keep their existing capability behavior. The Anthropic Messages adapter also inherits normalized citations, web-search source deduplication, manual-thinking tool-choice safeguards, and replayable file-reference/tool-search-error transcripts.
