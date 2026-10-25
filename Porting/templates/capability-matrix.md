# Provider Capability Matrix

Snapshot date: @@DATE@@

This document and `AIProviderCapabilities` are generated from
`Porting/packages.json`. Update the catalog, then run
`node Scripts/sdk.mjs generate`; runtime tests still verify actual coverage.

Legend:

- `L`: language
- `C`: completion
- `E`: embedding
- `I`: image
- `T`: transcription
- `S`: speech
- `AG`: audio generation
- `AT`: audio transformation
- `D`: dubbing
- `V`: video
- `R`: reranking
- `EV`: evaluation
- `DC`: decision
- `F`: file upload client
- `K`: skill upload client

@@TABLE@@

## Provider Notes

@@NOTES@@

## Reality Gates

Use three gates when judging provider completeness:

1. The provider appears in `AIProviderCapabilities.all`.
2. Unit tests cover the request and response or stream shape for every
   supported capability in the matrix.
3. At least one opt-in live smoke test exists for representative
   providers and can be run with real keys.

The live smoke suite is intentionally off by default. Run it with:

```sh
LIVE_AI_TESTS=1 swift test --filter LiveProviderSmoke
```

The suite reads `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`,
`DEEPSEEK_API_KEY`, `ASSEMBLYAI_API_KEY`, `ELEVENLABS_API_KEY`,
`CARTESIA_API_KEY`,
and `OPENAI_COMPATIBLE_API_KEY`.
When running from Xcode, set them as test environment variables in the
scheme instead of Run/Profile arguments.
Override model IDs with
`LIVE_OPENAI_MODEL`, `LIVE_ANTHROPIC_MODEL`, `LIVE_GOOGLE_MODEL`,
`LIVE_DEEPSEEK_MODEL`, `LIVE_ASSEMBLYAI_MODEL`, `LIVE_OPENAI_COMPATIBLE_MODEL`,
`LIVE_OPENAI_COMPATIBLE_BASE_URL`, `LIVE_ELEVENLABS_SPEECH_MODEL`,
`LIVE_ELEVENLABS_TRANSCRIPTION_MODEL`, `LIVE_ELEVENLABS_VOICE`,
`LIVE_CARTESIA_SPEECH_MODEL`, `LIVE_CARTESIA_TRANSCRIPTION_MODEL`,
and `LIVE_CARTESIA_VOICE`.
It covers text generation, text streaming, executable generate/stream tool loops,
OpenAI-compatible generation/streaming/completion/tool loops/object generation,
AssemblyAI transcription, ElevenLabs speech/transcription/audio generation/audio
transformation/dubbing, Cartesia speech/batch transcription, and representative embeddings.
Embedding checks also read
`LIVE_OPENAI_EMBEDDING_MODEL` and `LIVE_GOOGLE_EMBEDDING_MODEL`.
