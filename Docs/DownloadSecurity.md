# Download connection security

SwiftAISDK validates URLs returned by providers and URLs supplied for remote
media before downloading them. On macOS 12 and iOS 15 or later, the default
`URLSessionTransport` now also pins every untrusted download connection to
validated DNS addresses.

## What the default transport checks

For each HTTP or HTTPS hop, it resolves the hostname once, checks **every** IPv4
and IPv6 answer against the existing private/reserved-address restrictions, and
rejects the entire answer set if any address is disallowed. An empty answer or
an unsupported address also fails. The connector receives a numeric
`NWEndpoint.Host.ipv4` or `.ipv6` from that validated snapshot. Connection retries
use at most eight distinct addresses from the same snapshot; they do not perform
a second DNS lookup.

HTTPS retains the original hostname as TLS SNI and the name checked against the
certificate. Network.framework performs normal system certificate trust
evaluation, with TLS 1.2 as the minimum version. The HTTP `Host` header retains
the original authority. There is no certificate-verification bypass, numeric-URL
URLSession fallback, or shell networking subprocess.

Redirects remain manual and limited to ten. Every new destination goes through
the URL and DNS checks before it can connect. A redirect across origins drops
all caller headers except `User-Agent`, and credentials are not restored on a
later redirect back. Existing proxy, metadata, cookie and hop-by-hop request
header restrictions still apply.

The native download path uses HTTP/1.1 GET, requests `Accept-Encoding: identity`,
and fails explicitly if a server supplies another content encoding. It supports
fixed-length, chunked and connection-close response bodies, including HTTP error
bodies and interim responses. Conflicting lengths, transfer-encoding/length
ambiguity, invalid chunks, malformed headers and framing-related trailers fail
closed. Response headers are capped at 64 KiB and trailers at 16 KiB. Body size
limits apply both to declared and received bytes. Body reads are demand-driven
in chunks of at most 32 KiB.

Cancellation interrupts a pending connection/read and closes its socket.
Connection attempts time out after 15 seconds; DNS and individual I/O operations
time out after 30 seconds. The caller returns promptly when DNS is cancelled,
even if the operating system's synchronous resolver is still completing in the
background; a late result cannot start a connection. At most four system DNS
lookups run concurrently, and cancelled queued lookups are skipped.

Ordinary provider API requests continue to use URLSession. The pinned path is
dedicated to protected downloads and does not use URLSession's cookies, cache,
proxy configuration, authentication delegate, custom URL protocols, or client
certificate settings. Network.framework's TLS configuration is explicit; this
path does not apply an application's URLSession-specific ATS exceptions.

## Custom transports and sessions

`AITransport` adds `sendValidatedDownload(_:)`, and `AIStreamingTransport` adds
`streamValidatedDownload(_:)`. Existing conformers still compile. Their default
implementations throw `AIDownloadError` for untrusted downloads rather than
silently treating an ordinary hostname fetch as protected.

A custom networking implementation must implement these hooks with equivalent
connection-time DNS validation and numeric-address pinning, hostname TLS trust,
manual redirects, cancellation and byte limits. Calling ordinary `send` or
`stream` from a hook is appropriate only for an offline fixture or for an
implementation that already provides all those guarantees. Resolving and
checking a hostname before handing that hostname to URLSession is insufficient:
URLSession can perform a second resolution when it connects.

`URLSessionTransport(session: customSession)` explicitly rejects untrusted
downloads, because a custom session's proxy, trust and delegate semantics cannot
be preserved by silently substituting the native connector. Use the default
transport for protected downloads or provide a custom transport implementing
the protected hooks. Direct API requests on the injected session are unchanged.

## Configured trusted origins

The existing `trustedOrigin` parameter deliberately permits a
developer-configured self-hosted or local endpoint. An exact same-origin hop
uses the supplied transport's ordinary request method and skips the private
address/DNS restriction. Do not derive this value from a provider response or
other untrusted input. `credentialedOrigin` controls credentials; it does not
grant network trust. A redirect to another origin loses the exemption and must
use the protected download hook.

## Upstream and platform evidence

This port follows `@ai-sdk/provider-utils` 5.0.65 `createSafeLookup` and
`fetchWithValidatedRedirects`: all DNS answers are validated inside the
connection path, and custom fetch implementations own equivalent protection.
Swift makes missing custom-transport protection an explicit error.

Apple documents that
[`sec_protocol_options_set_tls_server_name`](https://developer.apple.com/documentation/security/sec_protocol_options_set_tls_server_name(_:_:))
overrides the endpoint name used to verify the peer certificate. Its SDK
availability is macOS 10.14 / iOS 12, below this package's platform minimums.

`HTTPDNSPinningTests` covers private/mixed answers, one-lookup retries, numeric
socket connection with an unresolvable original hostname, SNI, hostname trust,
custom transport/session rejection, trusted-origin redirects, strict framing,
body limits, cancellation, demand-driven reads and timeout-result lifetime. The
TLS fixture is imported into memory without changing the user keychain; those
certificate-fixture tests require macOS 15 / iOS 18, while the production
connection implementation supports macOS 12 / iOS 15.
