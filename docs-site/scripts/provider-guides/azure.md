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

Speech service errors retain their original HTTP status. A 502 response, including an Envoy protocol reset, remains retryable. Azure OpenAI image models keep their existing route.

## Shared Responses history and citations

Azure Responses inherits the OpenAI citation and retrieved-source separation, pruned-reasoning replay, and storage-disabled web-search replay. Ordinary tool results accept `providerMetadata.azure.additionalTools` with strict function definitions; each definition batch is inserted immediately after its result. Function omission uses `providerOptions.openai.omitFromRequestTools`, and omitted functions cannot be forced or allow-listed. Custom tool input streams expose text encoding. `AzureOpenAITools.webSearchPreview` is deprecated; use `webSearch`.


## Rotating API keys and tool search

`AzureOpenAIProviderSettings.apiKeyProvider` accepts an async throwing key supplier. Each request resolves its current key, using `api-key` for OpenAI and MAI and `Ocp-Apim-Subscription-Key` for Speech. Provider/request header overrides retain precedence. Configure either an API key supplier or the existing Entra `tokenProvider`.

`AzureOpenAITools.toolSearch()` exposes the hosted OpenAI tool-search protocol through Azure Responses. Function tools can set `providerOptions.azure.deferLoading: true`; the `openai` namespace remains a fallback. These options apply to both generation and streaming.

## Option namespaces, tools and timings

Chat/Completion and delegated OpenAI media merge `openai` options followed by
`azure`, so Azure keys win while unrelated OpenAI keys remain. Responses instead
uses the entire first-present `azure` namespace, falling back to `openai` only
when Azure is absent or null. Routing and Speech/MAI-only controls are filtered
before delegation.

`AzureOpenAITools` includes custom-tool, apply-patch and shell forwarding helpers.
OpenAI streaming transcription uses the configured WebSocket transport and merged
options; Azure Speech streaming remains unsupported. Speech file transcription
maps shared timestamp requests to provider timestamps when omitted and exposes
flattened `words` independently of phrases/segments. Excluded timings and
MAI-Transcribe-1.5 restrictions produce warnings.
