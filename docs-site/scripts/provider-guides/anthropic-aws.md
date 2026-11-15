## Quick start

```swift
import SwiftAISDK

let provider = try AIProviders.anthropicAWS(settings: AnthropicAWSProviderSettings(
    region: "us-east-1",
    workspaceID: "your-workspace-id"
))
let model = try provider.languageModel("claude-sonnet-4-6")
let result = try await model.generateText("Say hello from Claude Platform on AWS.")
print(result.text)
```

`AIProviders.anthropicAWS()` with no arguments reads the region and workspace from
the environment. With modular packages, `import SwiftAI` and
`import SwiftAIAnthropicAWS`, then call
`AIProviders.anthropicAWS(configuration: AnthropicAWSProviderSettings(...))`; the
native factory requires the configuration argument.

Requests go to `https://aws-external-anthropic.<region>.api.aws/v1` and carry an
`anthropic-workspace-id` header. A workspace ID is always required; a region is
required unless you set `baseURL`. The region must be a single DNS label.
`messages(...)` is an alias for `languageModel(...)`.

## Authentication

The provider picks the first available method:

1. `apiKeyProvider`: an async throwing closure called before each request. It must
   return a non-empty key; errors and blank values stop the request before it is
   sent.
2. `apiKey`, or `ANTHROPIC_AWS_API_KEY`, sent as `x-api-key`.
3. AWS SigV4 signing (service `aws-external-anthropic`) with `credentialProvider`,
   or with `accessKeyID`/`secretAccessKey`/`sessionToken`, or with
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN`.

```swift
let provider = try AIProviders.anthropicAWS(settings: AnthropicAWSProviderSettings(
    region: "us-east-1",
    workspaceID: "your-workspace-id",
    credentialProvider: {
        // Your own credential source, for example an STS AssumeRole call.
        let credentials = try await loadTemporaryAWSCredentials()
        return AnthropicAWSCredentials(
            accessKeyID: credentials.accessKeyID,
            secretAccessKey: credentials.secretAccessKey,
            sessionToken: credentials.sessionToken
        )
    }
))
```

The provider does not run the AWS SDK credential chain; supply credentials through
settings, a `credentialProvider` closure, or the environment variables above.
Header values with non-ASCII characters are sent but excluded from the signature.

## Messages features

The provider uses the same Messages adapter as [Anthropic](../anthropic/), so
`providerOptions["anthropic"]` (thinking, effort, cache control, structured output
mode and the rest), `AnthropicTools`, citations and streaming behave as described
there.

Message threads are enabled: pass `providerOptions["anthropic"]["thread"]` with
`["type": "create"]` or `["type": "continue", "previousMessageId": "msg_..."]`,
and keep the full history locally for recovery when a thread expires.

`provider.files()` and `provider.skills()` return Files and Skills clients for the
workspace. Message batches are only available on the direct Anthropic provider.
