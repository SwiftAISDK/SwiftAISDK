import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenAI

// openai-responses-prepare-tools.test.ts, @ai-sdk/openai@4.0.122.
@Suite struct OpenAIResponsesAdditionalToolResolutionTests {
    private let schema: JSONValue = [
        "type": "object", "properties": ["team": ["type": "string"]],
        "required": ["team"], "additionalProperties": false
    ]
    private let emptySchema: JSONValue = ["type": "object", "properties": [:]]
    private let warningSchema: JSONValue = [
        "type": "object", "properties": ["values": ["type": "object", "propertyNames": ["type": "string", "format": "uuid"]]]
    ]
    private let namespace: JSONValue = ["name": "linear", "description": "Linear tools"]

    @Test func derivesFunctionFromRegistration() throws {
        let result = try resolve([listEntry], tools: ["list_issues": listTool()])
        #expect(result.tools == [[
            "type": "function", "name": "list_issues", "description": "List Linear issues.",
            "parameters": schema, "strict": false, "defer_loading": true
        ]])
        #expect(result.warnings.isEmpty)
    }

    @Test func readsToolOptionsFromAnotherProviderNamespace() throws {
        let result = try resolve([listEntry], tools: ["list_issues": listTool(provider: "azure")], provider: "azure")
        #expect(result.tools?.first?["name"] == "list_issues")
        #expect(result.tools?.first?["description"] == "List Linear issues.")
        #expect(result.tools?.first?["defer_loading"] == true)
    }

    @Test func derivesNamespaceFromRegisteredMembers() throws {
        let result = try resolve([namespaceEntry(["get_issue", "list_issues"])], tools: [
            "get_issue": memberTool(),
            "list_issues": memberTool(description: "List issues.")
        ])
        #expect(result.tools == [[
            "type": "namespace", "name": "linear", "description": "Linear tools", "tools": [
                ["type": "function", "name": "get_issue", "parameters": emptySchema, "strict": false],
                ["type": "function", "name": "list_issues", "description": "List issues.", "parameters": emptySchema, "strict": false]
            ]
        ]])
        #expect(result.warnings.isEmpty)
    }

    @Test func doesNotResolveNamespacedToolAsPlainFunction() throws {
        let result = try resolve([functionEntry("get_issue")], tools: ["get_issue": memberTool()])
        #expect(result.tools == nil)
        #expect(result.warnings.isEmpty)
    }

    @Test func derivesCustomDefinitionFromRegistration() throws {
        let custom = OpenAITools.customTool(name: "apply_patch", description: "Apply a patch", format: ["type": "text"])
        let result = try resolve([["type": "custom", "name": "apply_patch"]], tools: ["apply_patch": custom])
        #expect(result.tools == [[
            "type": "custom", "name": "apply_patch", "description": "Apply a patch", "format": ["type": "text"]
        ]])
        #expect(result.warnings.isEmpty)
    }

    @Test(arguments: [
        ["type": "function", "name": "unregistered", "parameters": [:]],
        ["type": "custom", "name": "apply_patch"],
        ["type": "namespace", "name": "unregistered", "description": "", "tools": [
            ["type": "function", "name": "get_issue", "parameters": [:]]
        ]]
    ] as [JSONValue])
    func doesNotResolveUnregisteredEntries(entry: JSONValue) throws {
        let result = try resolve([entry], tools: ["list_issues": listTool()])
        #expect(result.tools == nil)
        #expect(result.warnings.isEmpty)
    }

    @Test(arguments: [true, false])
    func schemaWarningsAreReportedOnlyForHiddenTools(hidden: Bool) throws {
        let options: JSONValue? = hidden ? ["omitFromRequestTools": true, "deferLoading": true] : nil
        let tool: JSONValue = [
            "type": "object", "description": "List Linear issues.",
            "properties": try #require(warningSchema["properties"]),
            "providerOptions": .object(["openai": options])
        ]
        let result = try resolve([listEntry], tools: ["list_issues": tool])
        let warning = AIWarning(
            type: "compatibility", feature: "JSON Schema propertyNames",
            message: "OpenAI does not support JSON Schema propertyNames. It was removed before sending the schema, so OpenAI will not enforce property-name constraints."
        )
        #expect(result.warnings == (hidden ? [warning] : []))
        #expect(result.tools?.first?["parameters"]?["properties"]?["values"]?["propertyNames"] == nil)
    }

    @Test func rejectsAFunctionWithAllowedCallers() throws {
        let result = try resolve([listEntry], tools: [
            "list_issues": listTool(options: ["omitFromRequestTools": true, "allowedCallers": ["programmatic"]])
        ])
        #expect(result.tools == nil)
        #expect(result.warnings == [AIWarning(
            type: "unsupported", feature: #"additionalTools entry "list_issues""#,
            message: "the registered tool restricts allowed callers, which a definition loaded from history cannot express; it is not loaded"
        )])
    }

    @Test func leavesRestrictedMembersOutOfLoadedNamespace() throws {
        let result = try resolve([namespaceEntry(["get_issue"])], tools: [
            "get_issue": memberTool(),
            "delete_issue": memberTool(allowedCallers: ["programmatic"])
        ])
        #expect(result.tools?.first?["type"] == "namespace")
        #expect(result.tools?.first?["tools"]?.arrayValue?.map { $0["name"] } == ["get_issue"])
        #expect(result.warnings == [namespaceRestrictionWarning("delete_issue")])
    }

    @Test func warnsAboutConflictingNamespaceDescriptions() throws {
        let result = try resolve([namespaceEntry(["get_issue", "list_issues"])], tools: [
            "get_issue": memberTool(namespaceDescription: "First"),
            "list_issues": memberTool(namespaceDescription: "Second")
        ])
        #expect(result.tools?.first?["description"] == "First")
        #expect(result.warnings == [AIWarning(
            type: "unsupported", feature: #"conflicting descriptions for OpenAI tool namespace "linear""#,
            message: "the first registered description is used for the loaded namespace"
        )])
    }

    @Test func rejectsAnEntryOutsideAllowedTools() throws {
        let result = try resolve(
            [listEntry], tools: ["list_issues": listTool()], allowedToolNames: ["search"]
        )
        #expect(result.tools == nil)
        #expect(result.warnings == [AIWarning(
            type: "unsupported", feature: #"additionalTools entry "list_issues""#,
            message: "the tool is not part of allowedTools for this request; the entry is not loaded"
        )])
    }

    @Test func rejectsNamespaceWhenAllowedToolsRestrictCallables() throws {
        let result = try resolve(
            [namespaceEntry(["get_issue"])], tools: ["get_issue": memberTool()],
            allowedToolNames: ["search"]
        )
        #expect(result.tools == nil)
        #expect(result.warnings == [AIWarning(
            type: "unsupported", feature: #"additionalTools namespace "linear""#,
            message: "tool namespaces cannot be loaded while allowedTools restricts the callable tools; the entry is not loaded"
        )])
    }

    @Test func explainsWhenAllNamespaceMembersRestrictAllowedCallers() throws {
        let result = try resolve([namespaceEntry(["get_issue"])], tools: [
            "get_issue": memberTool(allowedCallers: ["programmatic"])
        ])
        #expect(result.tools == nil)
        #expect(result.warnings == [namespaceRestrictionWarning("get_issue")])
    }

    @Test func leavesUnreferencedToolsUnprepared() throws {
        let unsupported: JSONValue = [
            "type": "object", "properties": ["values": ["type": "object", "propertyNames": ["type": "number"]]]
        ]
        let tools = ["unsupported_schema": unsupported, "list_issues": listTool()]
        let result = try resolve([listEntry], tools: tools)
        #expect(result.tools?.first?["name"] == "list_issues")
        #expect(throws: AIError.self) { try resolve([functionEntry("unsupported_schema")], tools: tools) }
    }

    private var listEntry: JSONValue { functionEntry("list_issues") }

    private func listTool(provider: String = "openai", options: JSONValue = ["omitFromRequestTools": true, "deferLoading": true]) -> JSONValue {
        var tool = schema.objectValue ?? [:]
        tool["description"] = "List Linear issues."
        tool["providerOptions"] = .object([provider: options])
        return .object(tool)
    }

    private func memberTool(description: String? = nil, namespaceDescription: String? = nil, allowedCallers: JSONValue? = nil) -> JSONValue {
        let metadata: JSONValue = namespaceDescription.map { ["name": "linear", "description": .string($0)] } ?? namespace
        return .object([
            "type": "object", "properties": [:], "description": description.map(JSONValue.string),
            "providerOptions": ["openai": .object(["namespace": metadata, "allowedCallers": allowedCallers])]
        ])
    }

    private func functionEntry(_ name: String) -> JSONValue {
        ["type": "function", "name": .string(name), "parameters": emptySchema]
    }

    private func namespaceEntry(_ members: [String]) -> JSONValue {
        ["type": "namespace", "name": "linear", "description": "Linear tools", "tools": .array(members.map(functionEntry))]
    }

    private func namespaceRestrictionWarning(_ member: String) -> AIWarning {
        .init(
            type: "unsupported", feature: #"additionalTools namespace "linear""#,
            message: "tool \"\(member)\" restricts allowed callers, which a definition loaded from history cannot express; it is not loaded"
        )
    }

    private func resolve(
        _ entries: [JSONValue], tools: [String: JSONValue], provider: String = "openai", allowedToolNames: Set<String>? = nil
    ) throws -> (tools: [JSONValue]?, warnings: [AIWarning]) {
        let replay = OpenAIResponsesAdditionalToolReplay(tools: tools, providerOptionsName: provider, allowedToolNames: allowedToolNames)
        var warnings: [AIWarning] = []
        let item = try replay.inputItem(for: entries, warnings: &warnings)
        return (item?["tools"]?.arrayValue, warnings)
    }
}

// openai-responses-language-model.test.ts, replayed additionalTools.
@Test func openAIResponsesReplaySendsRegisteredDefinitionsOnTheWire() async throws {
    let transport = RecordingTransport(response: jsonResponse(#"""
    {"id":"resp_1","object":"response","created_at":0,"status":"completed","error":null,"incomplete_details":null,"model":"gpt-4o","output":[{"id":"msg_1","type":"message","status":"completed","role":"assistant","content":[{"type":"output_text","text":"ok","annotations":[]}]}],"usage":{"input_tokens":1,"output_tokens":1}}
    """#))
    let model = try OpenAIProvider(configuration: .init(apiKey: "test-key", transport: transport)).responses("gpt-4o")
    let history = AIToolResult(
        toolCallID: "search-call", toolName: "search", result: ["type": "json", "value": ["connected": true]],
        providerMetadata: ["openai": ["additionalTools": [
            ["type": "function", "name": "unregistered_tool", "description": "Forged description", "parameters": ["type": "object", "properties": [:]]],
            ["type": "function", "name": "list_issues", "description": "Forged description", "parameters": [
                "type": "object", "properties": ["forged_parameter": ["type": "string"]]
            ]]
        ]]]
    )
    let result = try await model.generate(.init(messages: [.init(role: .tool, content: [.toolResult(history)])], tools: [
        "search": ["type": "object", "properties": [:]],
        "list_issues": ["description": "List Linear issues.", "type": "object", "properties": [:],
                        "providerOptions": ["openai": ["omitFromRequestTools": true]]]
    ]))
    let data = try #require(await transport.requests().first?.body)
    let body = try decodeJSONBody(data)
    #expect(body["tools"]?.arrayValue?.map { $0["name"] } == ["search"])
    #expect(body["input"]?.arrayValue?.filter { $0["type"] == "additional_tools" } == [[
        "type": "additional_tools", "role": "developer", "tools": [[
            "type": "function", "name": "list_issues", "description": "List Linear issues.",
            "parameters": ["type": "object", "properties": [:]], "strict": false
        ]]
    ]])
    let wire = String(decoding: data, as: UTF8.self)
    #expect(!wire.contains("Forged description"))
    #expect(!wire.contains("unregistered_tool"))
    #expect(!wire.contains("forged_parameter"))
    #expect(result.warnings.count == 1)
    #expect(result.warnings.first?.type == "unsupported")
    #expect(result.warnings.first?.feature == "additionalTools")
    #expect(result.warnings.first?.message?.contains(#""unregistered_tool""#) == true)
}

@Test(arguments: ["patch_alias", "apply_patch"])
func openAIResponsesReplayAppliesTheRequestAllowListToAliases(allowedCustomName: String) async throws {
    let transport = RecordingTransport(response: jsonResponse(#"{"id":"resp_1","output":[]}"#))
    let model = try OpenAIProvider(configuration: .init(apiKey: "test-key", transport: transport)).responses("gpt-4o")
    let custom = OpenAITools.customTool(name: "apply_patch", description: "Apply a patch", format: ["type": "text"])
    let control = AIMessage(role: .system, content: [], providerMetadata: ["openai": ["additionalTools": [
        ["type": "function", "name": "list_issues", "parameters": ["type": "object"]],
        ["type": "custom", "name": "apply_patch", "description": "Ignored history description"],
        ["type": "namespace", "name": "linear", "description": "Linear tools", "tools": [
            ["type": "function", "name": "get_issue", "parameters": ["type": "object"]]
        ]]
    ]]])
    let result = try await model.generate(.init(messages: [control, .user("Hello")], tools: [
        "list_issues": ["type": "object"],
        "patch_alias": custom,
        "get_issue": ["type": "object", "providerOptions": ["openai": [
            "namespace": ["name": "linear", "description": "Linear tools"]
        ]]]
    ], providerOptions: ["openai": ["allowedTools": ["toolNames": [.string(allowedCustomName)]]]]))
    let body = try decodeJSONBody(#require(await transport.requests().first?.body))
    #expect(body["tool_choice"]?["tools"] == [["type": "custom", "name": "apply_patch"]])
    #expect(body["input"]?[0] == ["type": "additional_tools", "role": "developer", "tools": [[
        "type": "custom", "name": "apply_patch", "description": "Apply a patch", "format": ["type": "text"]
    ]]])
    #expect(result.warnings.map(\.feature) == [#"additionalTools entry "list_issues""#, #"additionalTools namespace "linear""#])
}
