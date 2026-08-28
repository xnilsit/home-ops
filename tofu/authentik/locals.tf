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

    # ── the LAN services proxied through external-services ────────────────────
    # Each pairs with a SecurityPolicy in
    # kubernetes/apps/network/external-services/app/oidc.yaml.
    code = {
      display_name = "Code"
      description  = "code-server on the NAS."
      hostnames    = ["code.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    duplicacy = {
      display_name = "Duplicacy"
      description  = "Backup console."
      hostnames    = ["backup.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    oni = {
      display_name = "Oni"
      hostnames    = ["oni.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    openspeedtest = {
      display_name = "OpenSpeedTest"
      hostnames    = ["ost.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    scrutiny = {
      display_name = "Scrutiny"
      description  = "Disk SMART monitoring."
      hostnames    = ["scrutiny.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    unbalanced = {
      display_name = "Unbalanced"
      hostnames    = ["unbalanced.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    unraid = {
      display_name = "Unraid"
      description  = "NAS administration."
      hostnames    = ["unraid.${var.domain}"]
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
  }

  group_ids = { for k, g in authentik_group.this : k => g.id }
}
