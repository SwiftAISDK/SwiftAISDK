## Model-aware portable reasoning

Fireworks forwards portable reasoning values directly for most models. Families whose model names start with `gpt-oss`, `glm-5p3`, or `muse-spark` map `none` to `minimal`. `nemotron` and `inkling` families map `minimal` to `low`. Only these adaptations add compatibility warnings. Explicit provider `reasoningEffort` and raw request-body effort values pass through unchanged. `configureFireworksChat` installs the same policy for custom compatible hosting integrations.

## Rotating credentials

`FireworksProviderSettings.apiKeyProvider` accepts an async throwing closure resolved before each authenticated request, including asynchronous image submission, polling and trusted downloads. Provider/request authorization overrides keep precedence; a supplier failure stops the request before I/O.
