# SwiftAIUI

Optional Swift-native UI layer for SwiftAISDK. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.

Import `SwiftAIUI` for UI messages, validation and conversion, stream reduction,
`DirectAIChatTransport`, `AIChatSession`, and `createAgentUIStream`.
`AIChatSession` uses Combine and main-actor isolation for native application state.
The core agent and its request options remain in `swift-ai-core`, which does not
import this package. This is not a port of React components or browser rendering.

Delivered steering messages are persisted with their IDs and step numbers.
Use `convertToModelMessages` to replay steering-containing UI history in the
correct assistant/tool/user order while preserving user content metadata.
The singular converter rejects embedded steering, and validation requires the
user role. Exhaustive switches over `AIUIMessagePart` must handle the new
steering-message case.

Run `swift test --package-path Packages/swift-ai-ui` in the canonical checkout.
Upstream mappings and existing UI gaps remain in `Porting/map.json` and the
canonical capability documentation. Distribution manifests are catalog-generated.
