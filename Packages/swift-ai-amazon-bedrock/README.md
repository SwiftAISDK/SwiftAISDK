# SwiftAIAmazonBedrock

Swift-native port of `@ai-sdk/amazon-bedrock`. Maintained in the canonical SwiftAISDK repository and exported as an independent Swift package.
Sources are owned by the canonical repository, with shared HTTP/SigV4 machinery
in core and Anthropic wire behavior in the Anthropic package.

Existing baselines and documented port gaps remain unchanged. See the canonical
provider guide and `Porting/map.json`.

See [provider usage and capabilities](https://github.com/SwiftAISDK/SwiftAISDK/blob/main/docs-site/scripts/provider-guides/amazon-bedrock.md) for authentication, options and supported surfaces.
