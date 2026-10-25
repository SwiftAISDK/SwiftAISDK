# SwiftAIMCP

Swift-native port of `@ai-sdk/mcp`. Extracted during M6; not yet published.

Import `SwiftAIMCP` for `MCPClient`, HTTP/stdio transports, OAuth helpers, MCP Apps
metadata and event delivery adapters. The existing client, transport and tool APIs
are preserved. MCP tool conversion uses `SwiftAI` from `swift-ai-core`; core does
not import MCP. Stdio remains limited to the supported host platforms.

Run `swift test --package-path Packages/swift-ai-mcp` in the canonical checkout.
Runtime and translated tests follow the versions and gaps in `Porting/map.json`
and the canonical version ledger. Distribution manifests are catalog-generated.
