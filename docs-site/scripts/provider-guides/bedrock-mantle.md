## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.bedrockMantle(settings: AmazonBedrockProviderSettings(
    region: "us-east-1"
))
let model = try provider.languageModel("openai.gpt-oss-120b")
let result = try await model.generateText("Explain Bedrock Mantle in one sentence.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIAmazonBedrock`, then call
`AIProviders.bedrockMantle(configuration: AmazonBedrockProviderSettings(...))`;
the native factory requires the configuration argument.

Bedrock Mantle exposes OpenAI-compatible endpoints at
`https://bedrock-mantle.<region>.api.aws`.

## Chat and Responses

- `languageModel(...)` and `chat(...)` use Chat Completions.
- `responses(...)` uses the Responses API.

```swift
let responses = try provider.responses("openai.gpt-oss-120b")
let answer = try await responses.generateText("List three uses for embeddings.")
```

The path is chosen from the model ID: OpenAI GPT models other than GPT-OSS
(`openai.gpt-...`), Gemma 4 (`google.gemma-4...`) and xAI (`xai....`) models use
`/openai/v1`; other models, including `openai.gpt-oss-...`, use `/v1`. A custom
`baseURL` replaces both. The Responses model does not request web-search source
lists, because Mantle does not accept that include.

Request options and results follow the [OpenAI-compatible](../openai-compatible/)
Chat and Responses adapters.

## Credentials and region

Authentication matches [Amazon Bedrock](../amazon-bedrock/#authentication):
`apiKeyProvider`, then `apiKey` or `AWS_BEARER_TOKEN_BEDROCK`, then
`credentialProvider`, then access keys from settings or `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` with optional `AWS_SESSION_TOKEN`. SigV4 requests are
signed for the `bedrock-mantle` service. The region comes from `region`,
`AWS_REGION` or `AWS_DEFAULT_REGION` and defaults to `us-east-1`; the
`AWS_ENDPOINT_URL*` variables are not used, so set `baseURL` to change the host.
