# Non-secret identifiers, for reading the applied state out of the runner log.
# The issuer is deliberately absent: components/oidc derives it from
# ${AUTHENTIK_URL} and ${APP}, and computing it twice invites drift.
output "oidc" {
  value = {
    for k, m in module.app : k => {
      provider_name = m.name
      slug          = m.slug
      client_id     = m.client_id
      redirect_uris = m.redirect_uris
    }
  }
}
