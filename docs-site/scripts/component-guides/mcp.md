## OAuth resources and refresh bindings

The default OAuth resource validator checks protected-resource metadata and uses
the canonical server URL when no metadata resource is supplied. A custom
`validateResourceURL` hook may return nil to select that canonical URL. Canonical
resources drop fragments and include a slash for an otherwise empty path.

Refresh tokens retain their original authorization-server binding. That binding
is validated before dynamic client registration; an incompatible token is
invalidated before new client credentials are acquired. If invalidation leaves
the old token in storage, refresh fails rather than rebinding it to a new server.
Stored authorization-server information may omit client information.

OAuth discovery rejects HTTPS-to-HTTP redirects before following them and checks
the final response URL reported by custom transports. Existing address and
authorization-server binding validation remains applicable.

## Transports

`MCPHTTPTransport` matches upstream `{ type: 'http' }`: it starts in the
stateless protocol, so no inbound `GET` stream opens before `server/discover`.
Pass `initialProtocolVersion` to begin with a legacy session. HTTP redirects
are rejected unless `followRedirects: true` is set, and requests carry an
`ai-sdk/<version>` user-agent suffix. After a `202 Accepted`, a legacy session
re-opens its optional inbound SSE stream.

An HTTP POST event stream must return the JSON-RPC result or error for the
request ID. If the stream ends or disconnects first, the request throws
`MCPClientError`.

`MCPSSETransport` is the legacy HTTP+SSE transport (upstream `{ type: 'sse' }`).
It waits for the server's same-origin `endpoint` event, posts messages to that
endpoint and receives responses on the event stream. Its `onError` callback
reports stream parse failures and rejected posts. It requires a streaming
`AITransport`; managed event adapters receive `.custom` transport metadata for it.

## Tools

`tools()` returns dynamic tools whose `title` and `metadata` mirror upstream
`McpProviderMetadata` (`clientName`, `toolName`, `title`, known annotations and
MCP App `app` metadata). The converted input schema always sets
`additionalProperties: false`. `tools(schemas:)` returns only the named tools as
typed tools; with an `outputSchema`, successful results are replaced by their
validated `structuredContent` or parsed text content.

With `maxRetries`, transient tool-call failures retry after 2s, doubling per
attempt. A failure after the first attempt is wrapped in `MCPClientError`
(`Failed after N attempts...`). `MCPApps.fingerprint(_:)` and
`MCPApps.detectResourceDrift(current:baseline:)` detect MCP App resource changes,
and `MCPJSONRPC.validateMessage(_:)` validates JSON-RPC messages.
