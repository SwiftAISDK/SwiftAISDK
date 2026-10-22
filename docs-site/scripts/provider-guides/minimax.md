## M3.1 reasoning and sampling

`minimax-m3.1-flash` and later M-series versions support explicit reasoning effort, image/video input, and MiniMax cache markers. Model IDs are compared by numeric version components: M3.10 and M4 inherit these capabilities. M3.0, older models, and unrecognized IDs retain the earlier Anthropic-compatible behavior.

Set `reasoning` to `low`, `medium`, `high`, `xhigh`, or `max`, or pass `MiniMaxLanguageModelOptions(effort: .high).providerOptions`. `minimal` maps to low effort with a compatibility warning. `none` also maps to low effort with a warning because these models always reason. Explicit `minimax.effort` or `anthropic.effort` takes precedence. Omit reasoning or use `provider-default` to retain the server default.

When reasoning is mapped to MiniMax effort, usage metadata is available under both `anthropic` and `minimax` in generation results and stream finish metadata.

M3.1 and later accept temperature from 0 through 2. Temperature and top-p remain available with adaptive thinking; top-k is removed with a warning. Earlier models retain the Anthropic temperature and thinking restrictions.

## Images and video in chat

Use image URLs, inline `.data`/`.file` content, `.videoURL(...)`, or a video reference returned by MiniMax. Hosted image and video URLs pass through to the provider. Uploaded video IDs use the `minimax` reference key; the adapter adds `mm_file://` once. Image file references are unsupported.

```swift
let provider = try AIProviders.miniMax()
let model = try provider.languageModel("minimax-m3.1-flash")
let request = LanguageModelRequest(
    messages: [AIMessage(role: .user, content: [
        .text("Describe what changes between these scenes."),
        .imageURL(
            "https://example.com/scene.png",
            providerMetadata: MiniMaxImagePartOptions(detail: .high).providerOptions
        ),
        .videoURL(
            "https://example.com/clip.mp4",
            providerMetadata: MiniMaxVideoPartOptions(fps: 1).providerOptions
        ),
        .providerReference(mimeType: "video/mp4", reference: ["minimax": "uploaded-video-id"])
    ])],
    reasoning: "high"
)
let result = try await model.generate(request)
print(result.text)
```

Image detail supports `low`, `default`, or `high`. Video fps must be a finite number from 0.2 through 5. Omitted options use server defaults; invalid values fail before the request is sent. PDF input continues through the shared Anthropic document conversion. The same media and reasoning options work with `stream`.

## Prompt caching

Attach `MiniMaxCacheControlOptions(cacheControl: .ephemeral).providerOptions` as message or content-part `providerMetadata`. A message marker applies to its final block unless that block already has its own marker. The `minimax` namespace takes precedence over the canonical `anthropic` namespace; both `cacheControl` and `cache_control` spellings work. Up to four breakpoints are retained across prompt blocks and tools, with a warning for each excess marker. A marker does not guarantee a cache hit.

## Video generation

`videoModel(...)` continues to support async video operations and polling independently of chat video input. Persist the returned operation to resume status checks. Polling treats the task ID as one URL path segment, including IDs containing slashes or standalone dots. Chat file references require an existing uploaded MiniMax file; this provider does not add a file-upload client.
