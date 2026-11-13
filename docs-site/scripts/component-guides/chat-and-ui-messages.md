## Awaitable lifecycle and restored tools

`await session.stopAndWait()` waits for active send/reconnect consumer tasks to settle;
`await session.dispose()` also calls the transport's defaultable `close()`.
Existing synchronous `stop()` remains available. Cancellation suppresses an
automatic follow-up even when a restored or superseded stream settles later.
Custom transports own the completion of asynchronous producers that ignore
cancellation: the public stream contract has no producer-completion handle.

Use `AIUIMessageToolSchema` with schema-aware `validateUIMessages` or
`validateUIMessagesForAgent`. Async overloads accept `refineToolInput` callbacks
and check the preserved pre-refinement approval input before refinement.
DirectAIChatTransport bridges current tool refiners and output converters.

Agent normalization records `unavailableStaticToolCallIDs` for removed static
tools. Successful missing-tool outputs become an omission message; dynamic
outputs, errors and tools restored with a current converter keep their intended
model representation. Browser HTTP/WebSocket framing and explicit UI stream
step boundaries remain separate deferred surfaces.

When a streamed tool call reuses an ID, its latest nonempty name replaces the
previous name during input and completion. `pruneMessages` removes a reasoning
group when all following content before the next reasoning group was pruned;
reasoning attached to retained text/tools and trailing reasoning survive.

## Delivered steering history

The reducer persists `.steeringMessage` parts with their delivery ID, user message
and step number. `convertToModelMessages` expands them in assistant/tool/user order
and preserves user text/file metadata and references. Steering content must have
the user role. Use the plural conversion for this history: converting a single UI
message rejects embedded steering rather than dropping delivered user messages.
Consumers with exhaustive switches over `AIUIMessagePart` must handle the new case.

## Message queue and tool errors

`AIChatSession(transport: transport, experimentalQueue: true)` queues user
messages while a response or client tool is pending. Observe
`experimentalQueuedMessages`, remove an item with
`experimentalRemoveQueuedMessage(_:)`, or prioritize it with
`experimentalSendQueuedMessageNow(_:)`. Request headers, body and metadata stay
with each item. Stop/errors/interrupted responses pause the queue; sending another
message resumes it. Editing or regenerating clears it. Approval replies reach the
model before queued user messages. The original initializer retains immediate
replacement behavior; native automatic-send callbacks remain synchronous.

Tool errors retain the text already seen by the model. `AIUIMessageErrorOptions`
provides `redactToolErrors` and an optional `onError` formatter through reducer
snapshots, `createAgentUIStream`, or `DirectAIChatTransport.errorOptions`. A formatter
opts into redaction by default. Redacted tool errors can change restored reasoning
history; a compatibility warning appears when later reasoning is streamed.
Throw safe errors inside a tool when both the model and UI need a safe message.
Native failed-tool display uses `AIToolResult.isError`; browser chunk framing and
input-error state names are not a separate native protocol.

Validation reports the first invalid message/part/citation, and non-finite
provider/tool metadata produces a bounded issue. Opaque application data keeps
its existing typed behavior.
