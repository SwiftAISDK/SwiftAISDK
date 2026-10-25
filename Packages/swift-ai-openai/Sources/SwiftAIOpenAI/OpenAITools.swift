import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAICompatible
public enum OpenAITools {
    public static func applyPatch() -> JSONValue {
        providerTool(id: "openai.apply_patch", name: "apply_patch")
    }

    /// Source-compatible custom-tool factory retained from 1.6.0.
    public static func customTool(
        name: String,
        description: String? = nil,
        format: JSONValue? = nil
    ) -> JSONValue {
        customTool(name: name, description: description, format: format, async: nil)
    }

    public static func customTool(
        name: String,
        description: String? = nil,
        format: JSONValue? = nil,
        async: Bool?
    ) -> JSONValue {
        providerTool(id: "openai.custom", name: name, args: JSONValue.object([
            "description": description.map(JSONValue.string),
            "format": format,
            "async": async.map(JSONValue.bool)
        ]).objectValue ?? [:])
    }

    public static func codeInterpreter(container: JSONValue? = nil) -> JSONValue {
        providerTool(id: "openai.code_interpreter", name: "code_interpreter", args: JSONValue.object([
            "container": container
        ]).objectValue ?? [:])
    }

    public static func computerUse(displayWidth: Int? = nil, displayHeight: Int? = nil, environment: String? = nil, extraArgs: [String: JSONValue] = [:]) -> JSONValue {
        var args = extraArgs
        if let displayWidth { args["displayWidth"] = .number(Double(displayWidth)) }
        if let displayHeight { args["displayHeight"] = .number(Double(displayHeight)) }
        if let environment { args["environment"] = .string(environment) }
        return providerTool(id: "openai.computer_use", name: "computer_use", args: args)
    }

    /// OpenAI Responses computer tool. The model emits ordered UI actions and
    /// safety checks; callers return a screenshot through the normal tool-result path.
    public static func computer() -> JSONValue {
        providerTool(id: "openai.computer", name: "computer")
    }

    public static func fileSearch(vectorStoreIDs: [String], maxNumResults: Int? = nil, ranking: JSONValue? = nil, filters: JSONValue? = nil) -> JSONValue {
        providerTool(id: "openai.file_search", name: "file_search", args: JSONValue.object([
            "vectorStoreIds": .array(vectorStoreIDs),
            "maxNumResults": maxNumResults.map { .number(Double($0)) },
            "ranking": ranking,
            "filters": filters
        ]).objectValue ?? [:])
    }

    /// Source-compatible image-generation tool factory retained from 1.5.x.
    public static func imageGeneration(
        background: String? = nil,
        inputFidelity: String? = nil,
        inputImageMask: JSONValue? = nil,
        model: String? = nil,
        moderation: String? = nil,
        outputCompression: Int? = nil,
        outputFormat: String? = nil,
        partialImages: Int? = nil,
        quality: String? = nil,
        size: String? = nil
    ) -> JSONValue {
        imageGeneration(
            action: nil,
            background: background,
            inputFidelity: inputFidelity,
            inputImageMask: inputImageMask,
            model: model,
            moderation: moderation,
            outputCompression: outputCompression,
            outputFormat: outputFormat,
            partialImages: partialImages,
            quality: quality,
            size: size
        )
    }

    public static func imageGeneration(
        action: String? = nil,
        background: String? = nil,
        inputFidelity: String? = nil,
        inputImageMask: JSONValue? = nil,
        model: String? = nil,
        moderation: String? = nil,
        outputCompression: Int? = nil,
        outputFormat: String? = nil,
        partialImages: Int? = nil,
        quality: String? = nil,
        size: String? = nil
    ) -> JSONValue {
        providerTool(id: "openai.image_generation", name: "image_generation", args: JSONValue.object([
            "action": action.map(JSONValue.string),
            "background": background.map(JSONValue.string),
            "inputFidelity": inputFidelity.map(JSONValue.string),
            "inputImageMask": inputImageMask,
            "model": model.map(JSONValue.string),
            "moderation": moderation.map(JSONValue.string),
            "outputCompression": outputCompression.map { .number(Double($0)) },
            "outputFormat": outputFormat.map(JSONValue.string),
            "partialImages": partialImages.map { .number(Double($0)) },
            "quality": quality.map(JSONValue.string),
            "size": size.map(JSONValue.string)
        ]).objectValue ?? [:])
    }

    public static func localShell() -> JSONValue {
        providerTool(id: "openai.local_shell", name: "local_shell")
    }

    public static func shell(environment: JSONValue? = nil) -> JSONValue {
        providerTool(id: "openai.shell", name: "shell", args: JSONValue.object([
            "environment": environment
        ]).objectValue ?? [:])
    }

    public static func shellContainerAutoEnvironment(
        fileIDs: [String] = [],
        memoryLimit: String? = nil,
        networkPolicy: JSONValue? = nil,
        skills: [JSONValue] = []
    ) -> JSONValue {
        JSONValue.object([
            "type": .string("containerAuto"),
            "fileIds": fileIDs.isEmpty ? nil : .array(fileIDs),
            "memoryLimit": memoryLimit.map(JSONValue.string),
            "networkPolicy": networkPolicy,
            "skills": skills.isEmpty ? nil : .array(skills)
        ])
    }

    public static func shellContainerReferenceEnvironment(containerID: String) -> JSONValue {
        JSONValue.object([
            "type": .string("containerReference"),
            "containerId": .string(containerID)
        ])
    }

    public static func shellLocalEnvironment(skills: [JSONValue] = []) -> JSONValue {
        JSONValue.object([
            "type": .string("local"),
            "skills": skills.isEmpty ? nil : .array(skills)
        ])
    }

    public static func shellDisabledNetworkPolicy() -> JSONValue {
        ["type": "disabled"]
    }

    public static func shellAllowlistNetworkPolicy(allowedDomains: [String], domainSecrets: [JSONValue] = []) -> JSONValue {
        JSONValue.object([
            "type": .string("allowlist"),
            "allowedDomains": .array(allowedDomains),
            "domainSecrets": domainSecrets.isEmpty ? nil : .array(domainSecrets)
        ])
    }

    public static func shellDomainSecret(domain: String, name: String, value: String) -> JSONValue {
        [
            "domain": .string(domain),
            "name": .string(name),
            "value": .string(value)
        ]
    }

    public static func shellSkillReference(skillID: String, version: String? = nil) -> JSONValue {
        JSONValue.object([
            "type": .string("skillReference"),
            "skillId": .string(skillID),
            "version": version.map(JSONValue.string)
        ])
    }

    public static func shellSkillReference(providerReference: [String: String], version: String? = nil) -> JSONValue {
        JSONValue.object([
            "type": .string("skillReference"),
            "providerReference": .object(providerReference.mapValues(JSONValue.string)),
            "version": version.map(JSONValue.string)
        ])
    }

    public static func shellInlineSkill(name: String, description: String, base64ZipData: String) -> JSONValue {
        [
            "type": "inline",
            "name": .string(name),
            "description": .string(description),
            "source": [
                "type": "base64",
                "mediaType": "application/zip",
                "data": .string(base64ZipData)
            ]
        ]
    }

    public static func shellLocalSkill(name: String, description: String, path: String) -> JSONValue {
        [
            "name": .string(name),
            "description": .string(description),
            "path": .string(path)
        ]
    }

    @available(*, deprecated, message: "Use webSearch instead.")
    public static func webSearchPreview(searchContextSize: String? = nil, userLocation: JSONValue? = nil) -> JSONValue {
        providerTool(id: "openai.web_search_preview", name: "web_search_preview", args: JSONValue.object([
            "searchContextSize": searchContextSize.map(JSONValue.string),
            "userLocation": userLocation
        ]).objectValue ?? [:])
    }

    public static func webSearch(
        filters: JSONValue? = nil,
        externalWebAccess: Bool? = nil,
        searchContextSize: String? = nil,
        userLocation: JSONValue? = nil
    ) -> JSONValue {
        providerTool(id: "openai.web_search", name: "web_search", args: JSONValue.object([
            "filters": filters,
            "externalWebAccess": externalWebAccess.map(JSONValue.bool),
            "searchContextSize": searchContextSize.map(JSONValue.string),
            "userLocation": userLocation
        ]).objectValue ?? [:])
    }

    public static func mcp(
        serverLabel: String,
        allowedTools: JSONValue? = nil,
        authorization: String? = nil,
        connectorID: String? = nil,
        headers: JSONValue? = nil,
        requireApproval: JSONValue? = nil,
        serverDescription: String? = nil,
        serverURL: String? = nil
    ) -> JSONValue {
        providerTool(id: "openai.mcp", name: "mcp", args: JSONValue.object([
            "serverLabel": .string(serverLabel),
            "allowedTools": allowedTools,
            "authorization": authorization.map(JSONValue.string),
            "connectorId": connectorID.map(JSONValue.string),
            "headers": headers,
            "requireApproval": requireApproval,
            "serverDescription": serverDescription.map(JSONValue.string),
            "serverUrl": serverURL.map(JSONValue.string)
        ]).objectValue ?? [:])
    }

    public static func programmaticToolCalling(name: String = "programmatic_tool_calling") -> JSONValue {
        providerTool(id: "openai.programmatic_tool_calling", name: name)
    }

    public static func toolSearch(execution: JSONValue? = nil, description: String? = nil, parameters: JSONValue? = nil) -> JSONValue {
        providerTool(id: "openai.tool_search", name: "tool_search", args: JSONValue.object([
            "execution": execution,
            "description": description.map(JSONValue.string),
            "parameters": parameters
        ]).objectValue ?? [:])
    }

    static func providerTool(id: String, name: String, args: [String: JSONValue] = [:]) -> JSONValue {
        .object([
            "type": .string("provider"),
            "id": .string(id),
            "name": .string(name),
            "args": .object(args)
        ])
    }
}
public struct OpenResponsesErrorMetadata: Equatable, Sendable {
    public var statusCode: Int?
    public var isRetryable: Bool?

    public init(statusCode: Int? = nil, isRetryable: Bool? = nil) {
        self.statusCode = statusCode
        self.isRetryable = isRetryable
    }
}
public struct OpenResponsesFailedResponse: Equatable, Sendable {
    public var statusCode: Int?
    public var responseBody: String
    public var isRetryable: Bool?

    public init(statusCode: Int? = nil, responseBody: String, isRetryable: Bool? = nil) {
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.isRetryable = isRetryable
    }
}
