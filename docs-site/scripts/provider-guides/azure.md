## Deployment names and underlying models

```swift
let azure = try AIProviders.azure(resourceName: "my-resource")
let model = try azure.responses(
    "production-deployment",
    settings: AzureOpenAILanguageModelSettings(modelID: "gpt-5")
)
```

The deployment name remains in the request body and deployment-based URL. `model.modelID` reports the underlying model, so Responses and Chat apply the correct reasoning, sampling and system-message rules even when the deployment has a custom name. Returned response metadata preserves the server's model ID. The same settings overload is available on the callable provider, `languageModel`, `chat`/`chatModel`, and `completion`/`completionModel`. Omitting settings or leaving `modelID` unset preserves the deployment name as the model identity.

## MAI image generation and editing

```swift
let azure = try AIProviders.azure(resourceName: "my-resource")
let image = try azure.imageModel("mai-image-2.5")
let result = try await image.generateImage(.init(
    prompt: "A watercolor mountain village",
    aspectRatio: "16:9"
))
print(result.base64Images.count)
```

MAI image models use their own `/images/generations` and `/images/edits` routes, aspect-ratio/pixel-budget sizing, reference-image uploads and Azure/Entra authentication. `AzureOpenAIAudioSettings.maiBaseURL` configures a custom MAI host. The image request's `files` selects editing; unsupported masks warn. Unknown deployment IDs can opt into `providerOptions.azure.api: "mai"`.

Speech reset errors retain the original 502 wire response but report a nonretryable typed 400 with voice guidance, avoiding retries for an invalid voice. Azure OpenAI image models keep their existing route.

## Shared Responses history and citations

Azure Responses inherits the OpenAI citation and retrieved-source separation, pruned-reasoning replay, and storage-disabled web-search replay. Ordinary tool results accept `providerMetadata.azure.additionalTools` with strict function definitions; each definition batch is inserted immediately after its result. Function omission uses `providerOptions.openai.omitFromRequestTools`, and omitted functions cannot be forced or allow-listed. Custom tool input streams expose text encoding. `AzureOpenAITools.webSearchPreview` is deprecated; use `webSearch`.
