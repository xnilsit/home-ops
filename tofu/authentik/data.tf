# authentik is owned by the other cluster. Everything here is read, never created.

# Implicit consent: these are all first-party services, and explicit consent
# puts an "Authorize Application" click in front of every login.
data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

# Required by authentik's ProviderSerializer; omitting it is a 400 at apply.
data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

# Looked up by `managed` id, not name: the names are localised display strings.
# offline_access is load-bearing - authentik only issues a refresh token when it
# is granted, and without one SecurityPolicy's refreshToken: true is a no-op.
data "authentik_property_mapping_provider_scope" "oidc" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-offline_access",
  ]
}

# Without a signing key authentik signs id_tokens HS256 with the client secret,
# leaving them unverifiable by anything holding only the JWKS.
data "authentik_certificate_key_pair" "signing" {
  name = "authentik Self-signed Certificate"
  # Both default to true and would pull the private key into tfstate. Only .id
  # is used here.
  fetch_certificate = false
  fetch_key         = false
}
