## Embedding formats and usage

Cohere embeddings accept output dimensions 256, 512, 768, 1024, 1536 and 2048. `providerOptions.cohere.embeddingType` selects float (default), int8, uint8, binary or ubinary; the parser requires the matching response array. Packed binary values remain numeric bytes rather than being unpacked. Provider dimensions override generic request dimensions.

Input cache-read usage is recorded separately and subtracted from uncached input tokens, while raw provider usage remains available in generation and streaming.

## Rotating credentials

The native `CohereProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.


## Text documents and reasoning

Text documents use native `Data` bytes decoded as UTF-8. Decode base64 transport values into `Data` before constructing a file part; plain text that looks like base64 remains literal text. File titles, Unicode text and document order are retained. If portable reasoning cannot map to a token budget, the request still enables thinking without inventing a budget and returns the unsupported-reasoning warning.

## Current request and response behavior

Document citations are emitted for unary and streaming responses, including
partial citations and a single citation in a `citation-start` event. Tool-output-only
citations remain in the raw response and are not represented as document sources.
The first source containing a document supplies its title; arbitrary document
metadata is retained. Token usage comes only from `usage.tokens`; billed units
remain in raw usage and are never substituted for token counts.
