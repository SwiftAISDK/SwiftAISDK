Hugging Face language calls use its Responses endpoint. A tool choice of
`["type": "none"]` is forwarded as `tool_choice: "none"` while preserving the
supplied function definitions.

If the SSE body ends before a completion event, the terminal part reports
`finishReason == "interrupted"`. Malformed JSON and provider errors remain
observable error parts and finish with `"error"`. Received text, reasoning,
usage and metadata remain available through the native stream parts.

## Rotating credentials

The native `HuggingFaceProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.
