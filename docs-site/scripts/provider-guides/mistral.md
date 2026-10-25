## Conversations API

```swift
let mistral = try AIProviders.mistral()
let model = try mistral.conversation("mistral-small-latest")
let result = try await model.generate(.init(
    messages: [.user("Find recent astronomy news.")],
    tools: ["web_search": MistralTools.webSearch()]
))
print(result.text)
```

`conversation(...)` uses `/conversations` with typed Mistral options, system instructions, file/image input, function and provider tools, sources, usage and streaming event conversion. `MistralTools.webSearchPremium()` exposes premium search. Every call is stateless (`store=false`) and replays the full prompt; conversation or agent continuation IDs are not exposed. Existing `languageModel(...)` and `chatModel(...)` retain Chat Completions.

A schema plus application tools on Chat Completions uses the synthetic JSON tool; its arguments become output text without hiding real application calls. Generic embedding dimensions are forwarded unless provider-specific dimensions override them.

## Reasoning configuration for future models

Unknown chat model IDs inherit support for top-level reasoning and the `mistral.reasoningEffort` override. The override keeps precedence. Known non-reasoning Codestral, Ministral, legacy Mistral Large and Voxtral IDs retain their previous unsupported behavior.

## Voxtral 3 speech and transcription

Speech IDs such as `voxtral-mini-tts-3-0` and `voxtral-mini-tts-3` accept
`providerOptions.mistral.expressiveness` from 1 through 5 and `phonemeHints`, a
dictionary mapping words to nonempty arrays of IPA phonemes. Inline delivery
tags remain in the input text. Existing `refAudio` still takes precedence over
`voice`.

```swift
let speech = try mistral.speech("voxtral-mini-tts-3")
let audio = try await speech.speak(.init(
    text: "[emotion=happy] I like tomato soup.",
    voice: "gb_jane_neutral",
    providerOptions: ["mistral": [
        "expressiveness": 1.5,
        "phonemeHints": ["tomato": ["t", "ə", "m", "ɑ", "t", "oʊ"]]
    ]]
))
```

Voxtral 3 transcription supports `voxtral-mini-transcribe-3` and
`voxtral-small-transcribe-3`, including their `-3-0` and `-latest` aliases.
`returnLanguage: true` requests detected language and cannot be combined with
a pinned `language`. Context bias accepts nonempty phrases and punctuation,
including more than 100 entries. Language plus timestamps is rejected only for
the known legacy `voxtral-mini-2507`, `voxtral-mini-2602` and
`voxtral-mini-latest` IDs. Current, future and custom model IDs forward that
combination. The API validates model-specific word timestamps and diarization
requirements.
