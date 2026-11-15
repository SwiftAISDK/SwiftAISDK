# SwiftAISDK MCP for Swift

`SwiftAIMCP` is the Model Context Protocol client for
[SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift
port of `@ai-sdk/mcp`. It provides `MCPClient`, Streamable HTTP and stdio
transports, OAuth helpers, MCP Apps metadata and event delivery adapters, and
converts MCP tools into `SwiftAI` tools that any language model can call.

- [MCP tools guide](https://swiftaisdk.github.io/SwiftAISDK/cookbook/mcp-tools/): connect a server, discover tools, OAuth
- [MCP events guide](https://swiftaisdk.github.io/SwiftAISDK/cookbook/mcp-events/): receive event webhooks
- [MCP API reference](https://swiftaisdk.github.io/SwiftAISDK/components/mcp/)

## Usage

Add the `SwiftAI` product from `swift-ai-core`, a provider package, and the
`SwiftAIMCP` product from this package to your target. The MCP tools guide shows
the complete flow from connecting a client to passing its tools to
`generateText`. Stdio transport is available on platforms that can launch
processes.

## Contributing

This package is exported from `Packages/swift-ai-mcp` in the canonical
[SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues
and pull requests there.
