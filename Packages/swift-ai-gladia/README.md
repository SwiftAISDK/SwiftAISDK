# SwiftAIGladia

Swift-native port of `@ai-sdk/gladia`, reviewed through npm 3.0.82. Source edits
belong to the canonical SwiftAISDK repository and are exported deterministically.

```swift
import SwiftAIGladia
import SwiftAIProvider

let provider = try GladiaProvider(configuration: .init(
    apiKey: "...", pollIntervalMs: 1_000, pollTimeoutMs: 600_000
))
let model = try provider.transcriptionModel("solaria-3")
let result = try await model.transcribe(.init(
    audio: wavData,
    providerOptions: ["gladia": .object([
        "languageConfig": .object(["languages": .array(["en"])]),
        "piiRedaction": true,
        "piiRedactionConfig": .object(["processedTextType": "MASK"])
    ])]
))
```

`transcriptionModel()` uses the native `"default"` sentinel, which omits the model
field and lets Gladia select its default. Explicit `"default"` behaves the same;
other explicit model IDs are sent unchanged. Solaria 3 expects exactly one language and
no code switching; incompatible settings produce warnings. Use
`languageConfig.languages` and `languageConfig.codeSwitching`. Legacy `language`,
`detectLanguage`, `enableCodeSwitching` and `codeSwitchingConfig` are translated
with deprecation warnings; an explicit `languageConfig` fully overrides them.

Boolean `customVocabulary` with `customVocabularyConfig.vocabulary` is the current
format. Legacy vocabulary arrays are translated, invalid entries are ignored with
a warning, and explicit vocabulary configuration wins. Obsolete context prompts,
moderation, chapterization, name consistency, structured extraction, display mode
and `diarizationConfig.enhanced` are ignored with unsupported warnings. Translation
supports batch models, lip sync, context adaptation/context and informal style;
audio-to-LLM accepts a model. PII configuration is validated before upload.

The native `transcribeFromURL(AudioURLTranscriptionRequest)` hook passes a public
HTTP(S) source URL directly to Gladia and skips uploading/downloading the audio.
It uses the same job options, validation, metadata and polling as uploaded bytes.
This is a Swift convenience over the provider's `audio_url` request field.

Provider and per-call `pollIntervalMs`/`pollTimeoutMs` must be positive integers;
per-call options take precedence. Defaults are 1 second and 10 minutes. Polling
and waits honor cancellation. Polling settings never reach the API body. Same-origin
polls include credentials; foreign result origins receive no credentials. The
`x-gladia-version` header defaults to `ai-sdk/3.0.82` and can be overridden.
Audio intelligence results and future add-on fields are preserved in provider
metadata without validating unused response shapes.

Run `swift test --package-path Packages/swift-ai-gladia --no-parallel` in the
canonical checkout. See `Porting/map.json` for reviewed coverage. Workflow
serialization of JavaScript model instances has no native Swift counterpart.

Original public initializer and helper signatures remain available for typed
function references, alongside the extended APIs. Their original defaults are preserved.
