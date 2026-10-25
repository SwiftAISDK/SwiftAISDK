Hugging Face language calls use its Responses endpoint. A tool choice of
`["type": "none"]` is forwarded as `tool_choice: "none"` while preserving the
supplied function definitions.

If the SSE body ends before a completion event, the terminal part reports
`finishReason == "interrupted"`. Malformed JSON and provider errors remain
observable error parts and finish with `"error"`. Received text, reasoning,
usage and metadata remain available through the native stream parts.
