## OAuth resources and refresh bindings

The default OAuth resource validator checks protected-resource metadata and uses
the canonical server URL when no metadata resource is supplied. A custom
`validateResourceURL` hook may return nil to select that canonical URL. Canonical
resources drop fragments and include a slash for an otherwise empty path.

Refresh tokens retain their original authorization-server binding. That binding
is validated before dynamic client registration; an incompatible token is
invalidated before new client credentials are acquired. If invalidation leaves
the old token in storage, refresh fails rather than rebinding it to a new server.
Stored authorization-server information may omit client information.

OAuth discovery rejects HTTPS-to-HTTP redirects before following them and checks
the final response URL reported by custom transports. Existing address and
authorization-server binding validation remains applicable.
