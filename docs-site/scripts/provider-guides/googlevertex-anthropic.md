## Request labels

Set `providerOptions["vertex"]["labels"]` to an object of string values to attach billing and usage labels to a Claude request. Generate and stream calls encode its UTF-8 JSON as a base64 `x-vertex-ai-labels` header. An explicit request or provider header takes precedence regardless of casing. Labels stay isolated to each call; they are omitted from the Anthropic request body. Invalid labels fail before network I/O.

## Native structured output selection

Ordinary automatic native schemas require explicit
`GoogleVertexHostedProviderSettings.supportsNativeStructuredOutput = true`,
a recognized Claude version of at least 4.5, and a Google Cloud organization
policy permitting `structured_outputs`. The setting defaults to false; strict
tool inputs remain disabled.

Shared Anthropic selection rules still apply: explicit `outputFormat` can
request native output, and models rejecting forced JSON tools use the lossless
native-schema fallback even when hosting defaults disable automatic selection.
Schemas that cannot be preserved keep the JSON-tool path in automatic mode.
The setting controls ordinary automatic selection; it is not a service-policy
enforcement switch.
