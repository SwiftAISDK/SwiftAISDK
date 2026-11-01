## Forward-compatible Wan video routing

Wan video requests choose their protocol from the numeric model version. Known `wan2.6` and earlier IDs, including the older `wanx2.1` prefix, retain legacy size fields. Wan 2.7 and later 2.x models use the tiered reference protocol. Wan 3+, and unrecognized future IDs, inherit the latest all-in-one media protocol with media inputs, tiered resolution and ratio handling.

## Rotating credentials

The native `AlibabaProviderSettings` accepts an optional
`apiKeyProvider` asynchronous throwing closure. It is resolved for each
authenticated request, so short-lived credentials can refresh without recreating
the provider or model. Static `apiKey` settings remain supported. A supplier
failure stops the request before it reaches the transport.
