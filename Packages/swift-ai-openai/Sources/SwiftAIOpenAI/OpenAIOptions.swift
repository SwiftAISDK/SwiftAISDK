import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
public func openAIImageHasDefaultResponseFormat(_ modelID: String) -> Bool {
    ["chatgpt-image-", "gpt-image-"].contains { modelID.hasPrefix($0) }
}
public func openAIImageMaxImagesPerCall(_ modelID: String) -> Int {
    switch modelID {
    case "dall-e-2",
         "gpt-image-1",
         "gpt-image-1-mini",
         "gpt-image-1.5",
         "gpt-image-2",
         "gpt-image-2.5-flare",
         "gpt-image-2.5-flare-2026-09-08",
         "gpt-image-2.5-sunburst",
         "gpt-image-2.5-sunburst-2026-09-08",
         "chatgpt-image-latest":
        return 10
    default:
        return modelID.hasPrefix("gpt-image-") ? 10 : 1
    }
}
func openAITranscriptionOptions(from extraBody: [String: JSONValue], providerID: String = "openai", providerRoot: String? = nil, modelID: String) -> [String: JSONValue] {
    var output = openAIProviderOptions(from: extraBody, providerID: providerID, providerRoot: providerRoot)
    let hadProviderOptions = !output.isEmpty
    openAIResponsesMoveKey("timestampGranularities", to: "timestamp_granularities", in: &output)
    openAIResponsesMoveKey("responseFormat", to: "response_format", in: &output)

    if modelID != "whisper-1", hadProviderOptions, output["response_format"] == nil {
        output["response_format"] = .string(openAITranscriptionUsesJSONResponseFormat(modelID) ? "json" : "verbose_json")
    }

    return output
}
func openAITranscriptionOptions(providerOptions: [String: JSONValue], extraBody: [String: JSONValue], providerID: String = "openai", providerRoot: String? = nil, modelID: String) throws -> [String: JSONValue] {
    var validatedProviderOptions = providerOptions
    for key in openAIProviderOptionNamespaceKeys(providerID: providerID, providerRoot: providerRoot) {
        guard var options = validatedProviderOptions[key]?.objectValue else { continue }
        for optionName in ["chunking_strategy", "chunkingStrategy"] {
            guard let chunkingStrategy = options[optionName] else { continue }
            options[optionName] = try openAIValidatedTranscriptionChunkingStrategy(
                chunkingStrategy,
                optionName: optionName
            )
        }
        validatedProviderOptions[key] = .object(options)
    }

    var output = openAIProviderOptions(providerOptions: validatedProviderOptions, extraBody: extraBody, providerID: providerID, providerRoot: providerRoot)
    let hadProviderOptions = !output.isEmpty
    openAIResponsesMoveKey("timestampGranularities", to: "timestamp_granularities", in: &output)
    openAIResponsesMoveKey("responseFormat", to: "response_format", in: &output)
    openAIResponsesMoveKey("chunkingStrategy", to: "chunking_strategy", in: &output)

    if hadProviderOptions {
        output["temperature"] = output["temperature"] ?? .number(0)
        output["timestamp_granularities"] = output["timestamp_granularities"] ?? .array([.string("segment")])
    }

    if modelID != "whisper-1", hadProviderOptions, output["response_format"] == nil {
        output["response_format"] = .string(openAITranscriptionDefaultResponseFormat(modelID))
    }
    if modelID == "gpt-4o-transcribe-diarize" {
        output["response_format"] = output["response_format"] ?? .string("diarized_json")
        output["chunking_strategy"] = output["chunking_strategy"] ?? .string("auto")
    }
    if let strategy = output["chunking_strategy"]?.objectValue {
        var mapped: [String: JSONValue] = [:]
        if let value = strategy["type"] { mapped["type"] = value }
        if let value = strategy["threshold"] { mapped["threshold"] = value }
        if let value = strategy["prefixPaddingMs"] ?? strategy["prefix_padding_ms"] { mapped["prefix_padding_ms"] = value }
        if let value = strategy["silenceDurationMs"] ?? strategy["silence_duration_ms"] { mapped["silence_duration_ms"] = value }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(JSONValue.object(mapped)),
           let string = String(data: data, encoding: .utf8) {
            output["chunking_strategy"] = .string(string)
        }
    }

    return output
}
func openAITranscriptionUsesJSONResponseFormat(_ modelID: String) -> Bool {
    modelID == "gpt-4o-transcribe" || modelID == "gpt-4o-mini-transcribe"
}
private func openAITranscriptionDefaultResponseFormat(_ modelID: String) -> String {
    if modelID == "gpt-4o-transcribe-diarize" { return "diarized_json" }
    return openAITranscriptionUsesJSONResponseFormat(modelID) ? "json" : "verbose_json"
}

private func openAIValidatedTranscriptionChunkingStrategy(
    _ value: JSONValue,
    optionName: String
) throws -> JSONValue {
    let argument = "providerOptions.openai.\(optionName)"
    if let string = value.stringValue {
        guard string == "auto" else {
            throw AIError.invalidArgument(
                argument: argument,
                message: "OpenAI chunkingStrategy must be auto or a server_vad object."
            )
        }
        return value
    }

    guard let strategy = value.objectValue else {
        throw AIError.invalidArgument(
            argument: argument,
            message: "OpenAI chunkingStrategy must be auto or a server_vad object."
        )
    }
    guard strategy["type"]?.stringValue == "server_vad" else {
        throw AIError.invalidArgument(
            argument: "\(argument).type",
            message: "OpenAI chunkingStrategy.type must be server_vad."
        )
    }

    var mapped: [String: JSONValue] = ["type": .string("server_vad")]
    if let threshold = strategy["threshold"] {
        guard let number = threshold.doubleValue,
              number.isFinite,
              (0...1).contains(number) else {
            throw AIError.invalidArgument(
                argument: "\(argument).threshold",
                message: "OpenAI chunkingStrategy.threshold must be a number between 0 and 1."
            )
        }
        mapped["threshold"] = .number(number)
    }
    for name in ["prefix_padding_ms", "prefixPaddingMs"] {
        guard let prefixPadding = strategy[name] else { continue }
        mapped["prefix_padding_ms"] = try openAIValidatedTranscriptionPadding(
            prefixPadding,
            argument: "\(argument).\(name)",
            displayName: "prefixPaddingMs"
        )
    }
    for name in ["silence_duration_ms", "silenceDurationMs"] {
        guard let silenceDuration = strategy[name] else { continue }
        mapped["silence_duration_ms"] = try openAIValidatedTranscriptionPadding(
            silenceDuration,
            argument: "\(argument).\(name)",
            displayName: "silenceDurationMs"
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(JSONValue.object(mapped))
    guard let string = String(data: data, encoding: .utf8) else {
        throw AIError.invalidArgument(
            argument: argument,
            message: "OpenAI chunkingStrategy could not be encoded."
        )
    }
    return .string(string)
}
private func openAIValidatedTranscriptionPadding(
    _ value: JSONValue,
    argument: String,
    displayName: String
) throws -> JSONValue {
    guard let number = value.doubleValue,
          number.isFinite,
          number >= 0,
          number.rounded(.towardZero) == number else {
        throw AIError.invalidArgument(
            argument: argument,
            message: "OpenAI chunkingStrategy.\(displayName) must be a nonnegative integer."
        )
    }
    return .number(number)
}