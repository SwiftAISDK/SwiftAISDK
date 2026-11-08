import Testing
import SwiftAIOpenAI
import SwiftAIProvider

@Test func weeklyProviderSelectorCompatibilityOpenAIMCPReference() {
    let old: (String, JSONValue?, String?, String?, JSONValue?, JSONValue?, String?, String?) -> JSONValue = OpenAITools.mcp(serverLabel:allowedTools:authorization:connectorID:headers:requireApproval:serverDescription:serverURL:)
    let current: (String, JSONValue?, String?, String?, JSONValue?, JSONValue?, String?, String?, String?) -> JSONValue = OpenAITools.mcp(serverLabel:allowedTools:authorization:connectorID:headers:requireApproval:serverDescription:serverURL:tunnelID:)
    let actual = old("docs", ["search"], "auth", "connector", ["x-test": "value"], "never", "Documentation", "https://mcp.test")
    #expect(actual == current("docs", ["search"], "auth", "connector", ["x-test": "value"], "never", "Documentation", "https://mcp.test", nil))
    #expect(actual["args"]?["allowedTools"] == ["search"])
    #expect(actual["args"]?["authorization"] == "auth" && actual["args"]?["connectorId"] == "connector")
    #expect(actual["args"]?["headers"]?["x-test"] == "value" && actual["args"]?["requireApproval"] == "never")
    #expect(actual["args"]?["serverDescription"] == "Documentation" && actual["args"]?["serverUrl"] == "https://mcp.test")
    #expect(actual["args"]?["tunnelId"] == nil)
    #expect(OpenAITools.mcp(serverLabel: "docs") == current("docs", nil, nil, nil, nil, nil, nil, nil, nil))
    #expect(current("docs", nil, nil, nil, nil, nil, nil, nil, "tunnel")["args"]?["tunnelId"] == "tunnel")
}
