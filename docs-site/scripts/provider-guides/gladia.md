## Rotating API keys

`GladiaProviderSettings` accepts an optional `apiKeyProvider`
asynchronous throwing closure. It is resolved for every authenticated request,
so credentials can refresh without recreating the provider or model. Static
`apiKey` settings remain supported. Supplier failures stop the request before
it reaches the transport.
## Current models, options and URL input

`GladiaProvider.transcriptionModel()` selects the service default. The native
`"default"` model-ID sentinel also omits the wire model; other explicit IDs pass
through. Solaria 3 expects exactly one language and no code switching, with
warnings for incompatible settings.

Use `languageConfig.languages` / `codeSwitching`. Legacy `language`,
`detectLanguage`, `enableCodeSwitching` and `codeSwitchingConfig` are translated
with deprecation warnings; an explicit `languageConfig` overrides them. Current
vocabulary uses Boolean `customVocabulary` plus
`customVocabularyConfig.vocabulary`; legacy arrays are translated and invalid
entries warn. Removed context/moderation/chapterization/extraction/display
settings warn and are ignored. Current PII, translation and audio-to-LLM options
are validated before upload.

Provider and per-call `pollIntervalMs` / `pollTimeoutMs` must be positive
integers, defaulting to 1 second / 10 minutes; call options win. Polling settings
stay out of the API body, and waits honor abort. `x-gladia-version` defaults to
`ai-sdk/3.0.77` and can be overridden. Future add-on fields remain in metadata.

The native URL-transcription hook passes an HTTP(S) audio URL directly to
`audio_url`, sharing job validation, polling and results while skipping the audio
upload/download. This is a Swift convenience over the provider's wire field.
