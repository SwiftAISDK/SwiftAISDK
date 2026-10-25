# Fresh Upstream Test Diff Audit

Snapshot date: 2026-10-25

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
