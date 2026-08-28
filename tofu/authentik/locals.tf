locals {
  # Adding a protected app is one entry here, plus the components/oidc component
  # in the app's own kustomization.yaml.
  #
  #   display_name  the tile's label on authentik's user dashboard
  #   hostnames     must match the HTTPRoute's hostnames exactly
  #   namespaces    where the credential Secret is reflected to
  #   groups        allowed in; EMPTY MEANS EVERY AUTHENTICATED USER
  apps = {
    echo = {
      display_name = "Echo"
      description  = "Request echo. Renders the request back as JSON."
      hostnames    = ["echo.${var.domain}"]
      namespaces   = ["default"]
      groups       = ["home-ops"]
    }
  }

  group_ids = { for k, g in authentik_group.this : k => g.id }
}
