import Foundation
import Testing
@testable import SwiftAISDK

// Published mistral@4.0.72 speech/transcription and gateway@4.0.126 search fixtures.
@Suite struct WeeklyMistralGateway20261025 {
    @Test func voxtralDeliveryControlsPreserveInlineTagsAndVoice() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"audio_data":"YXVkaW8="}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).speech("voxtral-mini-tts-3-0")
        let result = try await model.speak(.init(
            text: "[emotion=happy] I like tomato soup.", voice: "gb_jane_neutral",
            providerOptions: ["mistral": ["expressiveness": 1.5, "phonemeHints": ["tomato": ["t", "ə", "m", "ɑ", "t", "oʊ"]]]]
        ))
        let body = try decodeJSONBody(try #require(await transport.requests().first?.body))
        #expect(body["input"] == "[emotion=happy] I like tomato soup.")
        #expect(body["voice_id"] == "gb_jane_neutral")
        #expect(body["expressiveness"] == 1.5)
        #expect(body["phoneme_hints"]?["tomato"] == ["t", "ə", "m", "ɑ", "t", "oʊ"])
        #expect(body["response_format"] == "mp3")
        #expect(body["stream"] == false)
        #expect(result.audio == Data("audio".utf8))
        #expect(result.warnings.isEmpty)
    }

    @Test(arguments: [
        JSONValue.object(["expressiveness": 0.9]), ["expressiveness": 5.1],
        ["expressiveness": "high"], ["phonemeHints": ["tomato": []]],
        ["phonemeHints": ["tomato": [""]]], ["phonemeHints": ["": ["t"]]]
    ])
    func invalidDeliveryControlsFailBeforeIO(_ options: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"audio_data":"YQ=="}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).speech("voxtral-mini-tts-3")
        await #expect(throws: AIError.self) {
            _ = try await model.speak(.init(text: "hello", providerOptions: ["mistral": options]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: ["voxtral-mini-transcribe-3-0", "voxtral-small-transcribe-3", "voxtral-mini-transcribe-4-0", "custom-transcription-model"])
    func currentAndUnknownTranscriptionModelsAllowPinnedLanguageWithTimestamps(_ modelID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"model":"voxtral","text":"hello","language":"en"}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).transcription(modelID)
        _ = try await model.transcribe(.init(audio: Data(), providerOptions: ["mistral": [
            "language": "en", "returnLanguage": false, "timestampGranularities": ["segment"], "diarize": true
        ]]))
        let request = try #require(await transport.requests().first)
        let body = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(body.contains("name=\"language\"\r\n\r\nen"))
        #expect(body.contains("name=\"return_language\"\r\n\r\nfalse"))
        #expect(body.contains("name=\"timestamp_granularities\"\r\n\r\nsegment"))
        #expect(body.contains("name=\"diarize\"\r\n\r\ntrue"))
    }

    @Test(arguments: ["voxtral-mini-2507", "voxtral-mini-2602", "voxtral-mini-latest"])
    func legacyTranscriptionModelsKeepPinnedLanguageRestriction(_ modelID: String) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"model":"voxtral","text":"hello"}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).transcription(modelID)
        await #expect(throws: AIError.self) {
            _ = try await model.transcribe(.init(audio: Data(), providerOptions: ["mistral": [
                "language": "en", "timestampGranularities": ["segment"]
            ]]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test func languagePredictionAndLongPhraseBiasMapToMultipart() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"model":"voxtral-mini-transcribe-3","text":"hello","language":"en"}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).transcription("voxtral-mini-transcribe-3")
        let phrases = ["AI SDK", "A conversation about Vercel, Swift, and speech."] + (0..<100).map { "Product \($0)" }
        let result = try await model.transcribe(.init(audio: Data(), providerOptions: ["mistral": [
            "returnLanguage": true, "contextBias": .array(phrases.map(JSONValue.string))
        ]]))
        let request = try #require(await transport.requests().first)
        let body = String(decoding: try #require(request.body), as: UTF8.self)
        #expect(body.contains("name=\"return_language\"\r\n\r\ntrue"))
        #expect(body.components(separatedBy: "name=\"context_bias\"").count - 1 == phrases.count)
        #expect(body.contains(phrases[1]))
        #expect(result.language == "en")
    }

    @Test(arguments: [
        JSONValue.object(["language": "en", "returnLanguage": true]),
        ["returnLanguage": "yes"], ["contextBias": [""]]
    ])
    func invalidTranscriptionOptionsFailBeforeIO(_ options: JSONValue) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"model":"voxtral","text":"hello"}"#))
        let model = try AIProviders.mistral(settings: .init(apiKey: "key", transport: transport)).transcription("voxtral-mini-transcribe-3")
        await #expect(throws: AIError.self) {
            _ = try await model.transcribe(.init(audio: Data(), providerOptions: ["mistral": options]))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test(arguments: ["turbo", "fast", "basic", "advanced", "one-shot", "agentic"])
    func parallelSearchGAKeepsModesAndMapsNewControls(_ mode: String) {
        let tool = GatewayTools.parallelSearch(
            mode: mode, includeDomains: ["docs.python.org/3"], maxCharsPerResult: 500,
            maxCharsTotal: 8_000, maxAgeSeconds: 600, timeoutSeconds: 10,
            disableCacheFallback: true, location: "jp"
        )
        let args = tool["args"]
        #expect(tool["id"] == "gateway.parallel_search")
        #expect(args?["mode"] == .string(mode))
        #expect(args?["sourcePolicy"]?["includeDomains"] == ["docs.python.org/3"])
        #expect(args?["excerpts"]?["maxCharsPerResult"] == 500)
        #expect(args?["excerpts"]?["maxCharsTotal"] == nil)
        #expect(args?["maxCharsTotal"] == 8_000)
        #expect(args?["fetchPolicy"]?["maxAgeSeconds"] == 600)
        #expect(args?["fetchPolicy"]?["timeoutSeconds"] == 10)
        #expect(args?["fetchPolicy"]?["disableCacheFallback"] == true)
        #expect(args?["location"] == "jp")
    }

    @Test(arguments: ["{\"answer\":1}", ""])
    func gatewayPreservesProviderSelectedStructuredText(_ selected: String) async throws {
        let payload: JSONValue = ["text": "draft then final", "structuredOutputText": .string(selected), "finishReason": "stop"]
        let response = AIHTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: try encodeJSONBody(payload))
        let transport = RecordingTransport(response: response)
        let model = try AIProviders.gateway(settings: .init(apiKey: "key", transport: transport)).languageModel("openai/gpt-6")
        let result = try await model.generate(.init(messages: [.user("answer")]))
        #expect(result.text == "draft then final")
        #expect(result.structuredOutputText == selected)
    }
}
