## Structured output model support

Every Moonshot model ID, including legacy `moonshot-v1-*` and custom/future IDs, forwards JSON Schema structured output. Capability detection no longer depends on the `kimi-k` family prefix.

Generated content follows Moonshot's order: reasoning, function tool calls, then
text; the `text` and `toolCalls` convenience fields remain available.
