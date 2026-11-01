## Request transforms with warnings

```swift
var settings = ProviderSettings(apiKey: "...")
settings.transformRequestBodyWithWarnings = { body, warnings in
    var body = body
    if body.removeValue(forKey: "seed") != nil {
        warnings.append(.init(type: "unsupported", feature: "seed", message: "The proxy ignores seeds."))
    }
    return body
}
```

The existing `transformRequestBody` callback remains available and runs first. The new callback can report changes alongside the transformed request. Normal request/response metadata and warning results include the resulting transformation.

The standard `AIProviders.openAICompatible(..., transformRequestBodyWithWarnings:)` overload also accepts this two-argument callback. It preserves the existing factory overloads and the optional earlier one-argument transform.

## Referenced files and returned image URLs

Chat user content and multipart tool-result content accept provider file references for every media type. References resolve against the configured provider identity and preserve compatible content metadata; a missing provider ID raises `AINoSuchProviderReferenceError`.

Image generation and edits accept base64, URL, and mixed image responses. Returned URLs are downloaded through the configured transport with the request abort signal and URL/redirect checks. Credentials and custom headers remain on the API origin. `base64Images` preserves image order, including downloaded bytes, while `urls` retains response URLs for existing callers.

## Generated content order

Unary generation places the separate reasoning block before text, followed by function tool calls. Content-array entries preserve their internal order after the separate reasoning block. This keeps `result.content` in the same reasoning-before-answer order as streamed output.


## Rotating credentials and reasoning adapters

`OpenAICompatibleProviderSettings.apiKeyProvider` accepts an async throwing key supplier resolved before each authenticated request. Static keys and explicit provider/request authorization headers remain available. Trusted returned image URLs resolve credentials at download time; cross-origin downloads retain the existing credential stripping policy.

Custom wire adapters can set `OpenAICompatibleModelConfiguration.mapReasoning` to map portable `reasoning` and append warnings. Explicit provider `reasoningEffort` bypasses this callback. Completion prompt errors include the content of a misplaced system message.
