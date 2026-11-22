import SwiftAIProvider

/// Resolves replayed history against this request's registered tools.
final class OpenAIResponsesAdditionalToolReplay {
    private struct Reference: Hashable {
        var type: String
        var name: String
    }

    private enum Resolution {
        case unregistered
        case registered(definition: JSONValue?, warnings: [AIWarning])
    }

    private let tools: [String: JSONValue]
    private let providerOptionsName: String
    private let normalizeSchemas: Bool
    private let allowedToolNames: Set<String>?
    private lazy var toolsInNameOrder = tools.sorted { $0.key < $1.key }
    private var resolutions: [Reference: Resolution] = [:]
    private var seenWarnings: [AIWarning] = []
    private var droppedNames: [String] = []
    private var seenDroppedNames: Set<String> = []

    init(
        tools: [String: JSONValue],
        providerOptionsName: String = "openai",
        normalizeSchemas: Bool = true,
        allowedToolNames: Set<String>? = nil
    ) {
        self.tools = tools
        self.providerOptionsName = providerOptionsName
        self.normalizeSchemas = normalizeSchemas
        self.allowedToolNames = allowedToolNames
    }

    func inputItem(for entries: [JSONValue], warnings: inout [AIWarning]) throws -> JSONValue? {
        var resolvedTools: [JSONValue] = []
        var seenDefinitions: Set<JSONValue> = []
        for entry in entries {
            guard let type = entry["type"]?.stringValue, let name = entry["name"]?.stringValue else { continue }
            let reference = Reference(type: type, name: name)
            let resolution: Resolution
            if let cached = resolutions[reference] {
                resolution = cached
            } else {
                resolution = try resolve(reference)
                resolutions[reference] = resolution
            }
            switch resolution {
            case .unregistered:
                drop(name)
            case let .registered(definition, resolutionWarnings):
                for warning in resolutionWarnings {
                    appendOnce(warning, to: &warnings)
                }
                guard let definition else { continue }
                if let warning = definitionMismatchWarning(entry: entry, definition: definition, reference: reference) {
                    appendOnce(warning, to: &warnings)
                }
                if let narrowed = narrowNamespace(definition, to: entry), seenDefinitions.insert(narrowed).inserted {
                    resolvedTools.append(narrowed)
                }
            }
        }
        guard !resolvedTools.isEmpty else { return nil }
        return ["type": "additional_tools", "role": "developer", "tools": .array(resolvedTools)]
    }

    func appendDroppedWarning(to warnings: inout [AIWarning]) {
        guard !droppedNames.isEmpty else { return }
        let quotedNames = droppedNames.prefix(5).map { name in
            let shortName = name.utf16.count > 80 ? String(decoding: name.utf16.prefix(80), as: UTF16.self) + "..." : name
            return openAIResponsesJSONString(.string(shortName)) ?? shortName
        }.joined(separator: ", ")
        let suffix = droppedNames.count > 5 ? " and \(droppedNames.count - 5) more" : ""
        warnings.append(AIWarning(
            type: "unsupported",
            feature: "additionalTools",
            message: "additional tool definitions are only sent for tools registered in the request; dropped the definitions of unregistered tools: \(quotedNames)\(suffix)"
        ))
    }

    private func resolve(_ reference: Reference) throws -> Resolution {
        switch reference.type {
        case "function":
            guard let tool = tools[reference.name],
                  openAIResponsesRegisteredProviderToolID(name: reference.name, tool: tool) == nil else {
                return .unregistered
            }
            let options = openAIResponsesRegisteredFunctionOptions(tool, providerOptionsName: providerOptionsName)
            if let namespace = options?["namespace"], namespace != .null { return .unregistered }
            if let warning = allowedToolsWarning(reference) { return .registered(definition: nil, warnings: [warning]) }
            if restrictsAllowedCallers(options) {
                return .registered(definition: nil, warnings: [AIWarning(
                    type: "unsupported",
                    feature: "additionalTools entry \"\(reference.name)\"",
                    message: "the registered tool restricts allowed callers, which a definition loaded from history cannot express; it is not loaded"
                )])
            }
            var warnings: [AIWarning] = []
            let definition = try functionDefinition(name: reference.name, tool: tool, options: options, warnings: &warnings)
            return .registered(definition: definition, warnings: warnings)
        case "custom":
            guard let (registeredName, tool) = toolsInNameOrder.first(where: { name, tool in
                openAIResponsesRegisteredProviderToolID(name: name, tool: tool) == "openai.custom"
                    && (tool["name"]?.stringValue ?? name) == reference.name
            }) else { return .unregistered }
            if let warning = allowedToolsWarning(reference, registeredName: registeredName) {
                return .registered(definition: nil, warnings: [warning])
            }
            return .registered(definition: try customDefinition(name: reference.name, tool: tool), warnings: [])
        case "namespace":
            return try resolveNamespace(name: reference.name)
        default:
            return .unregistered
        }
    }

    private func resolveNamespace(name: String) throws -> Resolution {
        var description: String?
        var members: [JSONValue] = []
        var warnings: [AIWarning] = []
        // Swift request tools are keyed by name. Use a stable order for namespace members and conflicting descriptions.
        for (toolName, tool) in toolsInNameOrder {
            guard openAIResponsesRegisteredProviderToolID(name: toolName, tool: tool) == nil else { continue }
            let options = openAIResponsesRegisteredFunctionOptions(tool, providerOptionsName: providerOptionsName)
            guard let namespace = options?["namespace"], namespace["name"]?.stringValue == name,
                  let namespaceDescription = namespace["description"]?.stringValue else { continue }
            if allowedToolNames != nil {
                return .registered(definition: nil, warnings: [AIWarning(
                    type: "unsupported",
                    feature: "additionalTools namespace \"\(name)\"",
                    message: "tool namespaces cannot be loaded while allowedTools restricts the callable tools; the entry is not loaded"
                )])
            }
            if let description, description != namespaceDescription {
                warnings.append(AIWarning(
                    type: "unsupported",
                    feature: "conflicting descriptions for OpenAI tool namespace \"\(name)\"",
                    message: "the first registered description is used for the loaded namespace"
                ))
            } else {
                description = namespaceDescription
            }
            if restrictsAllowedCallers(options) {
                warnings.append(AIWarning(
                    type: "unsupported",
                    feature: "additionalTools namespace \"\(name)\"",
                    message: "tool \"\(toolName)\" restricts allowed callers, which a definition loaded from history cannot express; it is not loaded"
                ))
            } else {
                members.append(try functionDefinition(name: toolName, tool: tool, options: options, warnings: &warnings))
            }
        }
        guard let description else { return .unregistered }
        guard !members.isEmpty else { return .registered(definition: nil, warnings: warnings) }
        let definition: JSONValue = [
            "type": "namespace", "name": .string(name), "description": .string(description), "tools": .array(members)
        ]
        return .registered(definition: definition, warnings: warnings)
    }

    private func functionDefinition(
        name: String,
        tool: JSONValue,
        options: [String: JSONValue]?,
        warnings: inout [AIWarning]
    ) throws -> JSONValue {
        var schemaWarnings: [AIWarning] = []
        var definition = try openAIResponsesRegisteredFunction(
            name: name,
            schema: tool,
            options: options,
            supportsAsyncToolCalling: nil,
            normalizeSchemas: normalizeSchemas,
            warnings: &schemaWarnings
        )
        definition.removeValue(forKey: "output_schema")
        definition.removeValue(forKey: "allowed_callers")
        if definition["defer_loading"] == .null { definition.removeValue(forKey: "defer_loading") }
        if definition["strict"] == .null { definition["strict"] = false }
        if (options?["omitFromRequestTools"] ?? options?["omit_from_request_tools"])?.boolValue == true {
            warnings.append(contentsOf: schemaWarnings)
        }
        return .object(definition)
    }

    private func customDefinition(name: String, tool: JSONValue) throws -> JSONValue {
        let args = tool["args"] ?? [:]
        guard args.objectValue != nil, args["async"] == nil || args["async"]?.boolValue != nil else {
            throw AIError.invalidArgument(argument: "tools.\(name).args", message: "Invalid OpenAI custom tool arguments.")
        }
        var definition: [String: JSONValue] = ["type": "custom", "name": .string(name)]
        definition["description"] = args["description"]
        if let format = args["format"] {
            var fields: [String: JSONValue] = [:]
            fields["type"] = format["type"]
            if format["type"] == "grammar" {
                fields["syntax"] = format["syntax"]
                fields["definition"] = format["definition"]
            }
            definition["format"] = .object(fields)
        }
        let value = JSONValue.object(definition)
        _ = try openAIResponsesValidatedAdditionalTools(.array([value]))
        return value
    }

    private func allowedToolsWarning(_ reference: Reference, registeredName: String? = nil) -> AIWarning? {
        guard let allowedToolNames else { return nil }
        let requestName = registeredName ?? reference.name
        if allowedToolNames.contains(requestName) { return nil }
        // A custom tool may have a distinct provider wire name. A direct registration wins over that alias.
        if requestName != reference.name, tools[reference.name] == nil, allowedToolNames.contains(reference.name) {
            return nil
        }
        return AIWarning(
            type: "unsupported",
            feature: "additionalTools entry \"\(reference.name)\"",
            message: "the tool is not part of allowedTools for this request; the entry is not loaded"
        )
    }

    private func restrictsAllowedCallers(_ options: [String: JSONValue]?) -> Bool {
        guard let allowedCallers = options?["allowedCallers"] ?? options?["allowed_callers"] else { return false }
        return allowedCallers != .null
    }

    private func narrowNamespace(_ definition: JSONValue, to entry: JSONValue) -> JSONValue? {
        guard var namespace = definition.objectValue, let registered = namespace["tools"]?.arrayValue else {
            return definition
        }
        let requested = entry["tools"]?.arrayValue?.compactMap { $0["name"]?.stringValue } ?? []
        let registeredNames = Set(registered.compactMap { $0["name"]?.stringValue })
        for name in requested where !registeredNames.contains(name) {
            drop(name)
        }
        let requestedNames = Set(requested)
        let selected = registered.filter { tool in
            tool["name"]?.stringValue.map(requestedNames.contains) ?? false
        }
        guard !selected.isEmpty else { return nil }
        namespace["tools"] = .array(selected)
        return .object(namespace)
    }

    private func definitionMismatchWarning(entry: JSONValue, definition: JSONValue, reference: Reference) -> AIWarning? {
        guard reference.type == "function" else { return nil }
        var fields: [String] = []
        if let strict = entry["strict"], strict != definition["strict"] { fields.append("strict") }
        if let deferLoading = entry["defer_loading"], deferLoading != (definition["defer_loading"] ?? false) {
            fields.append("defer_loading")
        }
        guard !fields.isEmpty else { return nil }
        return AIWarning(
            type: "unsupported",
            feature: "additionalTools entry \"\(reference.name)\"",
            message: "the history entry sets \(fields.joined(separator: " and ")) differently from the registered tool; the registered definition is sent"
        )
    }

    private func appendOnce(_ warning: AIWarning, to warnings: inout [AIWarning]) {
        if !seenWarnings.contains(warning) {
            seenWarnings.append(warning)
            warnings.append(warning)
        }
    }

    private func drop(_ name: String) {
        if seenDroppedNames.insert(name).inserted { droppedNames.append(name) }
    }
}
