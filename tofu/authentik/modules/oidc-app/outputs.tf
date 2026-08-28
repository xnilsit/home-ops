# Identifiers only. client_secret is never an output - it stays in tfstate and
# reaches the cluster as a Secret.

output "name" {
  value = authentik_provider_oauth2.this.name
}

output "slug" {
  value = authentik_application.this.slug
}

output "client_id" {
  value = authentik_provider_oauth2.this.client_id
}

output "redirect_uris" {
  value = [for u in local.redirect_uris : u.url]
}
