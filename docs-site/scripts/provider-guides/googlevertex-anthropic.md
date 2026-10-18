## Request labels

Set `providerOptions["vertex"]["labels"]` to an object of string values to attach billing and usage labels to a Claude request. Generate and stream calls encode its UTF-8 JSON as a base64 `x-vertex-ai-labels` header. An explicit request or provider header takes precedence regardless of casing. Labels stay isolated to each call; they are omitted from the Anthropic request body. Invalid labels fail before network I/O.
