## JSON output with function tools

Groq can combine `.json(schema: ...)` with application function tools using a collision-safe synthetic JSON response tool. Its arguments become JSON text while real application calls retain their lifecycle. Generation and streams omit the synthetic call and conversational prose. An explicit application tool choice is preserved; `none` selects the response tool. Portable reasoning `max` maps to high.

## Forward-compatible browser search

Browser search stays enabled for unknown model IDs, alongside ordinary function tools. Known unsupported models, including Gemma, legacy Llama/Mixtral, Kimi K2 and Qwen entries, omit browser search and report a model-specific warning. New compatible model names no longer require a Swift package update merely to retain the requested tool.

## Generated content order

Unary generation places the separate reasoning block before text, followed by function tool calls. This keeps `result.content` in the same reasoning-before-answer order as streamed output.

## Rotating credentials

The native `GroqProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.


## Model-aware disabled reasoning

For GPT-OSS models, portable `reasoning: "none"` maps to `low` with a compatibility warning because the model always reasons. Qwen `qwen/qwen3.6-27b` accepts `none` directly. Models without reasoning omit that setting and report an unsupported warning. Explicit provider options retain precedence.
