## Rotating API keys

`TogetherAIProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.

## JSON Schema support

The current verified model IDs send `response_format.type = json_schema`:
`deepseek-ai/DeepSeek-V4-Flash-0731`, `deepseek-ai/DeepSeek-V4.1-Flash`,
`deepseek-ai/DeepSeek-V4.1-Flash-1017`, `openai/gpt-oss-120b`, `zai-org/GLM-5.2`,
`zai-org/GLM-5.3-Flash`, `moonshotai/Kimi-K3`, and
`MiniMaxAI/MiniMax-M3.1-Flash`. Other IDs use `json_object` and omit the schema.
The `supportsStructuredOutputs` setting is an explicit opt-in for additional
models whose schema support you have verified.
