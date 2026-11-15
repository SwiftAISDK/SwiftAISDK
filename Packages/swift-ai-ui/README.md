# SwiftAISDK UI for Swift

`SwiftAIUI` is the optional Swift-native chat and UI-message layer for
[SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK). It provides
`AIUIMessage` values with validation and conversion to model messages, stream
reduction into UI snapshots, `DirectAIChatTransport`, the observable
`AIChatSession`, message queuing and `createAgentUIStream`. It is designed for
SwiftUI and other native state, not a port of React hooks or browser rendering.

- [Chat guide](https://swiftaisdk.github.io/SwiftAISDK/core/chat/)
- [Chat and UI messages API reference](https://swiftaisdk.github.io/SwiftAISDK/components/chat-and-ui-messages/)

## Usage

Add the `SwiftAI` product from `swift-ai-core`, a provider package, and the
`SwiftAIUI` product from this package to your target. The chat guide shows how to
create a session, send messages, render message parts and handle tool approvals.

## Contributing

This package is exported from `Packages/swift-ai-ui` in the canonical
[SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues
and pull requests there.
