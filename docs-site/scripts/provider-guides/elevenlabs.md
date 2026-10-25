## Speaker evidence in batch transcription

Scribe transcription defaults to diarization enabled and sends one explicit `diarize` multipart field. Set `providerOptions.elevenlabs.diarize` to false to disable it. Returned words, including speaker IDs, are preserved in `providerMetadata["elevenlabs"]["words"]` alongside normalized segments.

`audio_duration_secs`, when reported by Scribe, is the authoritative audio duration. The last word's end time remains the fallback.

## Incremental speech

`streamingSpeechModel` creates a native duplex WebSocket speech model. The
experimental facade accepts a complete string, finite text parts, or an
`AIStreamingTextInput` backed by an asynchronous producer.

```swift
let elevenLabs = try AIProviders.elevenLabs()
let model = try elevenLabs.streamingSpeechModel("eleven_flash_v2_5")
let result = try AI.experimentalStreamSpeech(
    model: model,
    request: StreamingSpeechRequest(
        text: .chunks(["Hello ", "from Swift."]),
        voice: "21m00Tcm4TlvDq8ikWAM",
        outputFormat: AIStreamingAudioFormat(mediaType: "audio/pcm", sampleRate: 24_000)
    )
)
for try await audio in try result.audioStream {
    // Feed each chunk to an audio player that accepts the selected format.
    _ = audio
}
let usage = try await result.usage
```

Audio chunks preserve generation order and may require concatenation or a
streaming decoder. Choose exactly one owner: `audioStream`, `fullStream`, or
awaited final metadata. Awaiting metadata first drains the stream. The facade
keeps no replay buffer. `fullStream` exposes audio, raw chunks and nonfatal error
parts; `audioStream` skips error parts and empty chunks. Both fail on an
incomplete stream. A stream that produces no audio throws
`AINoSpeechGeneratedError`, retaining the latest provider error as its cause.
Cancel the result, abort its request, or leave an iterator early to release the
input producer and socket. Pass `onConsumerCancel` when wrapping an external
producer in `AIStreamingTextInput`.

`providerOptions.elevenlabs.streaming` supports `autoMode`,
`chunkLengthSchedule` (nonempty, each value 50–500), `enableSsmlParsing`,
`inactivityTimeout` (integer 1–180 seconds), `syncAlignment`, and a native
`outputFormat` override. Portable MIME formats include MP3, PCM, μ-law, A-law and
Ogg Opus. Streaming pronunciation dictionary locators require `versionId`.
The API key is carried in the first WebSocket message and is omitted from
reported request metadata. Text deltas are held to word/CJK punctuation
boundaries, with a 100-code-point bound for text without boundaries. Usage counts
Unicode code points. Default sessions send idle keepalives; an explicit TTS
inactivity timeout disables them.

## Dialogue, music and sound effects

Streaming `eleven_v3*` and `eleven_v4*` models require
`providerOptions.elevenlabs.dialogue.voices` (1–10 voice IDs). Each
`SpeechTextPart.voice` selects a listed speaker; a changed voice or
`providerOptions.elevenlabs.newTurn = true` starts a new turn. V4 sends turns
incrementally; V3 buffers the script into one final message.
`eleven_v3_conversational` accepts exactly one voice. Dialogue alignment and
end-of-turn markers are preserved in audio provider metadata, including empty
audio parts carrying only a turn marker. Dialogue always sends idle keepalives
and warns about TTS-only controls it cannot apply.

Unary `speechModel` routes `providerOptions.elevenlabs.inputs` to
`/v1/text-to-dialogue` for V3/V4. Each input contains nonempty `text` and `voiceId`;
the array replaces the standard text and voice. Dialogue maps stability and
similarity settings and warns about ignored instructions, speed and unsupported
voice settings.

`music_*` models use `/v1/music`, with `musicLengthMs` (3,000–600,000),
`forceInstrumental`, `seed`, or a native snake_case `compositionPlan`. A plan
replaces the prompt and cannot be combined with `musicLengthMs` or
`forceInstrumental`. Music V1 section plans and V2+ generation/reference chunks
are validated. `eleven_text_to_sound*` uses `/v1/sound-generation`, with
`durationSeconds` (0.5–30), `promptInfluence` (0–1) and `loop`. Both return
`providerMetadata.elevenlabs.outputFormat` and the known requested duration.
Music and sound-effects models reject streaming speech before opening a socket.
Existing dedicated music/sound-effect methods remain available.
