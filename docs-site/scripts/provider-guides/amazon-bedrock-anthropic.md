## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.amazonBedrockAnthropic(settings: AmazonBedrockProviderSettings(
    region: "us-east-1"
))
let model = try provider.languageModel("anthropic.claude-haiku-4-5-20251001-v1:0")
let result = try await model.generateText("Say hello from Bedrock.")
print(result.text)
```

With modular packages, `import SwiftAI` and `import SwiftAIAmazonBedrock`, then call
`AIProviders.amazonBedrockAnthropic(configuration: AmazonBedrockProviderSettings(...))`;
the native factory requires the configuration argument. `messages(...)` is an
alias for `languageModel(...)`.

This provider sends Anthropic Messages requests to Bedrock `InvokeModel` and
`InvokeModelWithResponseStream` in Anthropic's native format, so Anthropic
provider options, `AnthropicTools` definitions and Anthropic cache control work
as they do with the direct API.
Use [Amazon Bedrock](../amazon-bedrock/) for Converse, embeddings, images and
reranking.

## Credentials and region

Authentication and region resolution are the same as for
[Amazon Bedrock](../amazon-bedrock/#authentication): `apiKeyProvider`, then
`apiKey` or `AWS_BEARER_TOKEN_BEDROCK`, then `credentialProvider`, then access
keys from settings or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. Unlike the
Converse provider, `AWS_SESSION_TOKEN` is also read when the access keys come
from settings. The endpoint can be overridden with `baseURL`,
`AWS_ENDPOINT_URL_BEDROCK_RUNTIME` or `AWS_ENDPOINT_URL`.

## Provider options

Options use the Anthropic shape and are read from `providerOptions["anthropic"]`
or `providerOptions["bedrock"]`:

```swift
let result = try await model.generateText(
    "Think through the trade-offs, then answer.",
    options: LanguageGenerationOptions(
        maxOutputTokens: 8_000,
        providerOptions: [
            "anthropic": [
                "thinking": ["type": "enabled", "budgetTokens": 4_000],
            ],
        ]
    )
)
```

See [Anthropic provider options](../anthropic/#provider-options) for thinking,
effort, cache control, structured output mode and the other keys. Requests use
`anthropic_version` `bedrock-2023-05-31`.

## Differences from the Anthropic API

- Native JSON Schema output and strict tools are sent only to Claude models that
  Bedrock accepts them for; other models fall back to a JSON response tool, or to
  native JSON output when the model rejects forced tool use and the schema can be
  represented exactly.
- Image URLs in prompts are downloaded and sent inline.
- `AnthropicTools.bash_20241022`, `textEditor_20241022` and `computer_20241022`
  are upgraded to the versions Bedrock accepts, and computer-use and tool-search
  beta flags are added to `anthropic_beta` automatically.
- Message threads, Files, Skills and message batches are not available.
