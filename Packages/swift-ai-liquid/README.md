# Liquid AI for Swift

`SwiftAILiquid` adds Liquid's native Decision V4 API to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK). Use text, JSON, images and audio to answer choice, score, boolean and box questions.

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAILiquid` product from this package. Set `LIQUID_API_KEY` or pass credentials in `LiquidProviderSettings`.

```swift
import SwiftAI
import SwiftAILiquid

let provider = createLiquid()
let model = provider.decisionModel("d1.2")
```

See the [Liquid AI provider guide](https://swiftaisdk.github.io/SwiftAISDK/providers/liquid/) for a runnable decision example and evidence limits.

This package is exported from the canonical [SwiftAISDK repository](https://github.com/SwiftAISDK/SwiftAISDK). Submit implementation changes there.
