# Fresh Upstream Test Diff Audit

Snapshot date: 2026-11-01

## 2026-11-01 inventory comparison

Compared `682e2dd71456f14f9da33a1b983d1998c3a1184c` with `dffe4053c15709577329518044b1ec1d4c6bb0fe` for discovery. The current inventory contains 1,124 executable paths in 86 groups. Exact published package test refs in [the weekly audit](WeeklyUpstreamAudit20261101.json) control parity; this main-to-main diff is not release-matched evidence.

| Change | Test path | Disposition |
| --- | --- | --- |
| `A` | `packages/ai/src/agent/tool-loop-agent-steering.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/agent/tool-loop-agent.test-d.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/agent/tool-loop-agent.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/batch/batch.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/decide/decide.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-speech/generate-speech.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-speech/stream-speech.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/generate-text/generate-text-steering.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-text/generate-text.test-d.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-text/generate-text.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-text/restricted-telemetry-dispatcher.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-text/smooth-stream.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/generate-text/steering.test-d.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/generate-text/steering.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/generate-text/stream-language-model-call.test-d.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/generate-text/stream-text-steering.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-text/stream-text.test-d.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/generate-text/stream-text.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/prompt/prepare-language-model-call-options.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/prompt/standardize-prompt.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/telemetry/create-telemetry-dispatcher.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/telemetry/tracing-channel.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/transcribe/stream-transcribe.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/transcribe/transcribe.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/ai/src/ui/process-ui-message-stream.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/ai/src/util/fix-json.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/util/is-caused-by-abort.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/ai/src/util/is-node-runtime.test.ts` | Exact paired package release-test delta reviewed for `ai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/amazon-bedrock/src/amazon-bedrock-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/amazon-bedrock`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/amazon-bedrock/src/amazon-bedrock-prepare-tools.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/amazon-bedrock`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/amazon-bedrock/src/anthropic/amazon-bedrock-anthropic-structured-output.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/amazon-bedrock`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/amazon-bedrock/src/convert-to-amazon-bedrock-chat-messages.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/amazon-bedrock`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/amazon-bedrock/src/mantle/bedrock-mantle-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/amazon-bedrock`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/anthropic-files.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/anthropic/src/anthropic-forced-tool-structured-output.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/anthropic/src/anthropic-json-response-tool-fallback.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/anthropic-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/anthropic-provider.test-d.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/anthropic-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/anthropic/src/has-circular-schema-reference.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/sanitize-json-schema.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/skills/anthropic-skills.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/anthropic/src/supports-native-structured-output-schema.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/tool/bash_20241022.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/anthropic/src/tool/bash_20250124.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/anthropic`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/azure/src/azure-openai-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/azure`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/azure/src/azure-openai-tools.test-d.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/azure`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/azure/src/azure-speech-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/azure`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/cerebras/src/cerebras-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/cerebras`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/cohere/src/cohere-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/cohere`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/cohere/src/convert-to-cohere-chat-prompt.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/cohere`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/deepseek/src/chat/deepseek-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/deepseek`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/devtools/src/integration.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/elevenlabs/src/elevenlabs-error.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/elevenlabs`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/elevenlabs/src/elevenlabs-music-response.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/elevenlabs`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/elevenlabs/src/elevenlabs-speech-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/elevenlabs`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/elevenlabs/src/elevenlabs-speech-stream.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/elevenlabs`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/elevenlabs/src/elevenlabs-transcription-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/elevenlabs`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/fireworks/src/fireworks-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/fireworks`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/fireworks/src/fireworks-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/fireworks`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/gateway/src/errors/as-gateway-error.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/gateway`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/gateway/src/gateway-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/gateway`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/gateway/src/gateway-speech-model-stream.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/gateway`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/gateway/src/gateway-transcription-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/gateway`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/google-vertex/src/anthropic/google-vertex-anthropic-structured-output.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/google-vertex`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/google/src/convert-to-google-messages.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/google`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/google/src/google-json-accumulator.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/google`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/google/src/google-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/google`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/groq/src/groq-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/groq`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/harness-acp/src/acp-harness.test-d.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/acp-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/acp-v1-bootstrap.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/acp-v1-lifecycle.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/acp-v1-settings.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/harness-acp/src/v1/bridge/builtin-tool-approval.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/bridge/create-emit-stream-event.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/harness-acp/src/v1/bridge/host-tool-call-resolver.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/bridge/host-tool-correlation.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/bridge/host-tool-mcp-http.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/bridge/host-tool-relay-authorization.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/bridge/host-tool-relay.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-acp/src/v1/bridge/permission-controller.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `D` | `packages/harness-acp/src/v1/bridge/resolve-host-tool-call.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-claude-code/src/bridge/claude-code-system-prompt.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-claude-code/src/bridge/index.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-claude-code/src/bridge/json-schema-to-zod.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/harness-claude-code/src/bridge/tool-schema-metadata.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-claude-code/src/claude-code-bridge-protocol.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-claude-code/src/claude-code-harness.test-d.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-claude-code/src/claude-code-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-codex/src/bridge/index.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-codex/src/codex-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-cursor/src/cursor-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-deepagents/src/deepagents-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-github-copilot/src/github-copilot-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-grok-build/src/grok-build-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-opencode/src/bridge/index.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-opencode/src/opencode-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-file-tool-path-policy.integration.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-harness.test-d.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-harness.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-mcp.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-paths.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-read-operations.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-remote-ops.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/harness-pi/src/pi-resources.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-resume-state.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/harness-pi/src/pi-session-storage.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness-pi/src/pi-session.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `D` | `packages/harness-pi/src/pi-workspace-mirror.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `D` | `packages/harness-pi/src/pi-workspace-vfs.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/agent/harness-agent.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/harness/src/agent/internal/denied-tool-output.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/agent/internal/run-prompt.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/agent/internal/turn-telemetry.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/agent/internal/validate-tool-call.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/bridge/reconnect.integration.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/utils/bridge-ready.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/harness/src/utils/sandbox-channel.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/heygen/src/heygen-video-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/heygen`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/mcp/src/tool/mcp-client.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/mcp`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/mcp/src/tool/mcp-http-transport.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/mcp`; native translation or explicit product boundary is in the structured audit. |
| `A` | `packages/mcp/src/tool/mcp-input-required.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/mcp`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/mistral/src/mistral-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/mistral`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/moonshotai/src/moonshotai-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/moonshotai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai-compatible/src/chat/openai-compatible-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai-compatible`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai-compatible/src/completion/openai-compatible-completion-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai-compatible`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai-compatible/src/openai-compatible-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai-compatible`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/chat/openai-chat-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/completion/openai-completion-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/live/openai-realtime-model-live.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/normalize-openai-json-schema.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/openai-batch.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/openai-decision.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/openai-language-model-capabilities.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/realtime/realtime-model-v4.test-d.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/responses/openai-responses-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/openai/src/transcription/openai-transcription-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/openai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/otel/src/legacy-open-telemetry.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/otel/src/open-telemetry.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/perplexity/src/perplexity-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/perplexity`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/provider-utils/src/map-reasoning-to-provider.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/provider-utils`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/provider-utils/src/schema.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/provider-utils/src/types/sandbox.test-d.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/provider-utils`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/provider-utils/src/uint8-utils.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/provider-utils`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/quiverai/src/quiverai-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/quiverai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/sandbox-just-bash/src/just-bash-sandbox-session.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-just-bash/src/just-bash-sandbox.test-d.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-vercel/src/utils.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-vercel/src/vercel-legacy-sandbox-provider.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-vercel/src/vercel-network-policy-manager.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `A` | `packages/sandbox-vercel/src/vercel-network-policy-response-rules.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-vercel/src/vercel-sandbox-session.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-vercel/src/vercel-sandbox.test-d.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/sandbox-vercel/src/vercel-sandbox.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/tool-bash/src/bash-tool.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/tool-web-fetch/src/web-fetch-tool.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/tui/src/agent-tui.test.ts` | Inventory-only discovery; no parity assertion. Review against a published package delta before advancing its baseline. |
| `M` | `packages/xai/src/responses/xai-responses-language-model.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/xai`; native translation or explicit product boundary is in the structured audit. |
| `M` | `packages/xai/src/supports-reasoning-effort.test.ts` | Exact paired package release-test delta reviewed for `@ai-sdk/xai`; native translation or explicit product boundary is in the structured audit. |

The detailed release-test dispositions include declaration-only fixtures and native/runtime adaptations separately. Existing JS framework, Node, sandbox and harness boundaries remain.

## Historical 2026-10-25 comparison

Compared [`5893e994f9d8`](https://github.com/vercel/ai/tree/5893e994f9d8ac705811d3caec3e8faf2cd281ce) with [`682e2dd71456`](https://github.com/vercel/ai/tree/682e2dd71456f14f9da33a1b983d1998c3a1184c). Published old/latest npm sources control parity; declarations are not counted as executed Swift tests.

The fresh diff contains **40 executable and 3 declaration paths**. Current inventory: **1,106 executable test/spec paths in 86 groups**. Focused native tests translate fixture behavior rather than duplicating the full corpus.

| Change | Upstream path | Disposition | Swift evidence / boundary |
| --- | --- | --- | --- |
| `M` | `packages/ai/src/generate-object/generate-object.test.ts` | `ported` | WeeklyCore20261025 and WeeklyApproval20261025: final JSON selection, none choice isolation, interruption and approval semantics. |
| `A` | `packages/ai/src/generate-speech/stream-speech.test.ts` | `ported` | WeeklySpeech20261025: stream ownership, input/options, metadata/errors, no-audio and cancellation. |
| `M` | `packages/ai/src/generate-text/generate-text.test.ts` | `ported` | WeeklyCore20261025 and WeeklyApproval20261025: final JSON selection, none choice isolation, interruption and approval semantics. |
| `M` | `packages/ai/src/generate-text/stream-text.test.ts` | `ported` | WeeklyCore20261025 and WeeklyApproval20261025: final JSON selection, none choice isolation, interruption and approval semantics. |
| `M` | `packages/ai/src/middleware/extract-json-middleware.test.ts` | `ported` | WeeklyMiddleware20261025: per-content extraction and selected structured text, retaining citations/metadata. |
| `M` | `packages/ai/src/middleware/extract-reasoning-middleware.test.ts` | `ported` | WeeklyMiddleware20261025: per-content extraction and selected structured text, retaining citations/metadata. |
| `A` | `packages/elevenlabs/src/elevenlabs-speech-model-options.test-d.ts` | `declaration-review` | TypeScript export/inference fixture reviewed against published declarations; native options and public signatures are validated in Swift builds/tests. |
| `M` | `packages/elevenlabs/src/elevenlabs-speech-model.test.ts` | `ported` | WeeklyElevenLabs20261025: dialogue/streaming, unary routing and composition-plan validation; retained ElevenLabs suites cover transcription duration. |
| `A` | `packages/elevenlabs/src/elevenlabs-speech-stream.test.ts` | `ported` | WeeklyElevenLabs20261025: dialogue/streaming, unary routing and composition-plan validation; retained ElevenLabs suites cover transcription duration. |
| `A` | `packages/gateway/src/gateway-speech-model-stream.test.ts` | `ported` | WeeklyGatewaySpeech20261025: WebSocket envelope/auth/secret routes, lifecycle and errors; root Gateway/Mistral suite covers GA search. |
| `M` | `packages/gateway/src/gateway-speech-model.test.ts` | `ported` | WeeklyGatewaySpeech20261025: WebSocket envelope/auth/secret routes, lifecycle and errors; root Gateway/Mistral suite covers GA search. |
| `M` | `packages/google/src/google-json-accumulator.test.ts` | `ported` | WeeklyLanguage20261025: continuation resets, nested empty argument containers, concatenated function/response-tool input JSON. |
| `M` | `packages/google/src/google-language-model.test.ts` | `ported` | WeeklyLanguage20261025: continuation resets, nested empty argument containers, concatenated function/response-tool input JSON. |
| `M` | `packages/harness-acp/src/acp-harness.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-acp/src/v1/bridge/model-mapping.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `A` | `packages/harness-acp/src/v1/bridge/resolve-acp-model-id.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-claude-code/src/bridge/create-emit-stream-event.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-claude-code/src/claude-code-harness.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-cline/src/cline-resume-state.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-cline/src/cline-session.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-codex/src/bridge/codex-app-server-driver.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-codex/src/codex-harness.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-deepagents/src/deepagents-harness.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `A` | `packages/harness-fx/src/fx-resume-state.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `A` | `packages/harness-github-copilot/src/github-copilot-gateway-model.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-opencode/src/opencode-harness.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness-pi/src/pi-resume-state.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `A` | `packages/harness/src/utils/bridge-endpoint.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `A` | `packages/harness/src/utils/bridge-web-socket.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/harness/src/utils/sandbox-channel.test.ts` | `out-of-scope` | External coding-agent sandbox/bridge/session product; shared endpoints, handshakes, state paths and replay require a distinct native runtime. |
| `M` | `packages/huggingface/src/responses/huggingface-responses-language-model.test.ts` | `ported` | WeeklyLanguage20261025 and WeeklyStructuredOutput20261025: interrupted streams, retained tool definitions under none. |
| `M` | `packages/mcp/src/tool/mcp-client.test.ts` | `ported` | WeeklyMCP20261025: strings, null and nonobject wrapped tool output. |
| `M` | `packages/moonshotai/src/convert-moonshotai-chat-usage.test.ts` | `ported` | WeeklyMoonshot20261025: cache controls/usage/header metadata, K3.1 aliases, object unions and local refs. |
| `M` | `packages/moonshotai/src/moonshotai-chat-language-model.test.ts` | `ported` | WeeklyMoonshot20261025: cache controls/usage/header metadata, K3.1 aliases, object unions and local refs. |
| `M` | `packages/moonshotai/src/moonshotai-chat-options.test-d.ts` | `declaration-review` | TypeScript export/inference fixture reviewed against published declarations; native options and public signatures are validated in Swift builds/tests. |
| `M` | `packages/moonshotai/src/moonshotai-provider.test-d.ts` | `declaration-review` | TypeScript export/inference fixture reviewed against published declarations; native options and public signatures are validated in Swift builds/tests. |
| `M` | `packages/moonshotai/src/normalize-json-schema-for-mfjs.test.ts` | `ported` | WeeklyMoonshot20261025: cache controls/usage/header metadata, K3.1 aliases, object unions and local refs. |
| `M` | `packages/openai/src/responses/openai-responses-language-model.test.ts` | `ported` | WeeklyStructuredOutput20261025: last final_answer selection, explicit empty/malformed choices and retained full text/content. |
| `M` | `packages/otel/src/open-telemetry.test.ts` | `out-of-scope` | JS OpenTelemetry root-agent span naming; no native JS telemetry adapter imported. |
| `A` | `packages/provider-utils/src/speech-stream-envelope.test.ts` | `ported` | WeeklyGatewaySpeech20261025 and WeeklySpeech20261025: native speech envelope parser/serialization validation. |
| `A` | `packages/tool-web-fetch/src/web-fetch-tool.test.ts` | `out-of-scope; new tooling` | New provider-independent web-fetch tool; separate native policy/download/conversion/cache design recommended; not automatically implemented. |
| `M` | `packages/workflow/src/do-generate-step.test.ts` | `out-of-scope; native equivalent covered` | JS workflow execution/custom-part replay is not a native runtime; core none/interrupted semantics are covered independently. |
| `M` | `packages/workflow/src/do-stream-step.test.ts` | `out-of-scope; native equivalent covered` | JS workflow execution/custom-part replay is not a native runtime; core none/interrupted semantics are covered independently. |

## Previously inspected fixtures promoted into published scope

The prior snapshot already contained interrupted-stream, duplicate-approval and Parallel Search GA tests. Their implementations were then ahead of npm; the current published archives now contain the behavior. These retained fixture paths were reread for this pass:

| Upstream area | Swift evidence |
| --- | --- |
| AI collect-tool-approvals, stream-language-model-call and native chat tests | WeeklyApproval20261025, WeeklyCore20261025: first-response idempotency, none callback/part isolation, sticky interrupted chat. |
| Alibaba, Bedrock, Anthropic, Cohere, DeepSeek, Groq, Mistral chat, OpenResponses, Perplexity and xAI stream tests | WeeklyLanguage20261025: partial/empty output, explicit terminal controls, parse errors and one native terminal response. Anthropic retains first-message_stop cancellation; JS later-message bodies are a documented native difference. |
| OpenAI Chat and Completion stream tests | WeeklyLanguage20261025: interrupted vs explicit unknown/error; generic compatible retains its earlier missing-finish validation. |
| Google continue-google-stream and Interactions stream-transform tests | WeeklyLanguage20261025: empty/failed continuation state and terminal status handling. |
| Mistral speech/transcription tests | WeeklyMistralGateway20261025: Voxtral 3 delivery controls, language prediction, legacy restrictions and phrase bias. |
| Gateway parallel-search tests/declarations | WeeklyMistralGateway20261025: GA config budget/modes/fetch/location; raw GA response fields remain available. |

Existing low-memory JS result/replay/getter contracts, browser UI wire steps, framework/workflow/harness/sandbox products and provider-specific gaps remain documented in PortingStatus. No paid live provider calls were used.
