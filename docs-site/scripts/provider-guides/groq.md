## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.groq()
let model = try provider.languageModel("llama-3.3-70b-versatile")
let result = try await model.generateText("Name three fast-growing trees.")
print(result.text)
```

For a smaller dependency graph, use `import SwiftAI` and `import SwiftAIGroq` with
the native factory `AIProviders.groq(configuration: GroqProviderSettings())`. The
native factory requires the configuration argument; `GroqProviderSettings()` reads
`GROQ_API_KEY` from the environment.

Chat uses `/openai/v1/chat/completions` and transcription uses
`/openai/v1/audio/transcriptions`. Embedding and image models are not available.

## Provider options

Chat models read `providerOptions["groq"]`:

```swift
let model = try provider.languageModel("openai/gpt-oss-120b")
let result = try await model.generateText(
    "How many prime numbers are there below 100?",
    options: LanguageGenerationOptions(providerOptions: [
        "groq": [
            "reasoningEffort": "high",
            "reasoningFormat": "parsed",
            "serviceTier": "flex",
        ],
    ])
)
print(result.reasoning)
```

| Key | Values |
| --- | --- |
| `reasoningFormat` | `parsed`, `raw`, `hidden` |
| `reasoningEffort` | `none`, `default`, `low`, `medium`, `high` |
| `parallelToolCalls`, `structuredOutputs`, `strictJsonSchema` | Booleans |
| `user` | String |
| `serviceTier` | `on_demand`, `performance`, `flex`, `auto` |

Invalid values fail before the request is sent.

## Reasoning

The portable `reasoning` option maps to `reasoning_effort` unless
`providerOptions["groq"]["reasoningEffort"]` is set.

- GPT-OSS models always reason, so `none` becomes `low` with a compatibility
  warning. `qwen/qwen3.6-27b` accepts `none` directly.
- `max` maps to `high`.
- Models without reasoning ignore the setting with an unsupported warning.

Reasoning from Qwen and GPT-OSS models is returned as reasoning content, placed
before the answer text and tool calls in `result.content`.

## Structured output and tools

Function tools and JSON Schema output both work, in generation and streaming.
When you combine `.json(schema:)` with your own tools, the SDK adds an internal
response tool and turns its arguments into the JSON text; your real tool calls
keep their normal lifecycle. Tool choice `none` selects the response tool.

`GroqTools.browserSearch()` enables Groq's built-in browser search:

```swift
let result = try await model.generate(LanguageModelRequest(
    messages: [.user("What is the latest Swift release?")],
    tools: ["search": GroqTools.browserSearch()]
))
```

Browser search is sent for unknown and new model IDs. Models known not to support
it (Gemma, older Llama and Mixtral, Kimi K2 and some Qwen models) drop the tool
with a model-specific warning.

## Transcription

```swift
let whisper = try provider.transcriptionModel("whisper-large-v3-turbo")
let transcript = try await whisper.transcribe(
    audio: audioData,
    fileName: "memo.m4a",
    mimeType: "audio/mp4",
    providerOptions: ["groq": ["language": "en", "timestampGranularities": ["word"]]]
)
```

Options: `language`, `prompt`, `responseFormat`, `temperature` and
`timestampGranularities`. Plain-text responses are accepted, and when no segments
are returned, word timings are used as segments.

Pass an HTTP(S) URL with `AI.transcribe(model:request: AudioURLTranscriptionRequest(...))`
to have Groq fetch the audio itself. URLs with user info are rejected, fragments
are removed and your API headers are never sent to the audio host. If Groq cannot
follow a redirect, the SDK falls back to downloading the audio and uploading it.

## Rotating credentials

`GroqProviderSettings(apiKeyProvider:)` takes an async throwing closure that is
called before every authenticated request, so short-lived keys refresh without
recreating the provider. If the closure throws, the request is not sent.
