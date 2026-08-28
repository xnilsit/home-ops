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
      # code-server is VS Code in a browser; selfh.st has no own mark for it.
      icon       = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/visual-studio-code.svg"
      namespaces = ["network"]
      groups     = ["home-ops"]
    }
    duplicacy = {
      display_name = "Duplicacy"
      description  = "Backup console."
      hostnames    = ["backup.${var.domain}"]
      # Vendor logo: selfh.st has duplicati, a different product.
      icon       = "https://duplicacy.com/images/logo.png"
      namespaces = ["network"]
      groups     = ["home-ops"]
    }
    oni = {
      display_name = "Oni"
      hostnames    = ["oni.${var.domain}"]
      # 192.168.0.200:5000 is Synology DSM.
      icon       = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/synology.svg"
      namespaces = ["network"]
      groups     = ["home-ops"]
    }
    openspeedtest = {
      display_name = "OpenSpeedTest"
      hostnames    = ["ost.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/openspeedtest.svg"
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    scrutiny = {
      display_name = "Scrutiny"
      description  = "Disk SMART monitoring."
      hostnames    = ["scrutiny.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/scrutiny.svg"
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
    unbalanced = {
      display_name = "Unbalanced"
      hostnames    = ["unbalanced.${var.domain}"]
      # An Unraid plugin, so it borrows the Unraid mark.
      icon       = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/unraid.svg"
      namespaces = ["network"]
      groups     = ["home-ops"]
    }
    unraid = {
      display_name = "Unraid"
      description  = "NAS administration."
      hostnames    = ["unraid.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/unraid.svg"
      namespaces   = ["network"]
      groups       = ["home-ops"]
    }
  }

  group_ids = { for k, g in authentik_group.this : k => g.id }
}
