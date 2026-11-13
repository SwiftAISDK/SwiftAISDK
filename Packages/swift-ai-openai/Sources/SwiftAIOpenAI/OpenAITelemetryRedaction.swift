import SwiftAIProvider

/// Produces a telemetry-only copy; request and response values used by applications remain unchanged.
func openAIRedactedTelemetry(_ value: JSONValue) -> JSONValue {
    guard var output = value.objectValue else { return value }
    let type = output["type"]?.stringValue
    let id = output["id"]?.stringValue
    if let id, ["openai.mcp", "openai.code_interpreter", "openai.shell"].contains(id),
       let args = output["args"] {
        output["args"] = openAIRedactedToolArgs(args, type: String(id.dropFirst("openai.".count)))
    }
    if ["mcp", "code_interpreter", "shell"].contains(type ?? "") {
        return openAIRedactedToolArgs(.object(output), type: type!)
    }
    // A standardized provider tool can supply its argument object without its wrapper.
    if output["serverLabel"] != nil || output["server_label"] != nil {
        return openAIRedactedToolArgs(.object(output), type: "mcp")
    }
    for key in ["container", "environment"] {
        if let container = output[key]?.objectValue { output[key] = .object(openAIRedactedNetworkPolicy(container)) }
    }
    // Only the provider-owned tools collection is traversed. Prompt/input text,
    // generated content and arbitrary application JSON are not redaction targets.
    if let tools = output["tools"]?.arrayValue {
        output["tools"] = .array(tools.map(openAIRedactedTelemetry))
    } else if let tools = output["tools"]?.objectValue {
        output["tools"] = .object(tools.mapValues(openAIRedactedTelemetry))
    }
    return .object(output)
}

private func openAIRedactedToolArgs(_ value: JSONValue, type: String) -> JSONValue {
    guard var args = value.objectValue else { return value }
    if type == "mcp" {
        if let authorization = args["authorization"], authorization != .null { args["authorization"] = "[redacted]" }
        if let headers = args["headers"]?.objectValue { args["headers"] = .object(headers.mapValues { _ in "[redacted]" }) }
    } else {
        let key = type == "code_interpreter" ? "container" : "environment"
        if let container = args[key]?.objectValue { args[key] = .object(openAIRedactedNetworkPolicy(container)) }
    }
    return .object(args)
}

private func openAIRedactedNetworkPolicy(_ container: [String: JSONValue]) -> [String: JSONValue] {
    var container = container
    for policyKey in ["networkPolicy", "network_policy"] {
        guard var policy = container[policyKey]?.objectValue else { continue }
        for secretsKey in ["domainSecrets", "domain_secrets"] {
            guard let secrets = policy[secretsKey]?.arrayValue else { continue }
            policy[secretsKey] = .array(secrets.map { secret in
                guard var secret = secret.objectValue, secret["value"] != nil else { return secret }
                secret["value"] = "[redacted]"
                return .object(secret)
            })
        }
        container[policyKey] = .object(policy)
    }
    return container
}
