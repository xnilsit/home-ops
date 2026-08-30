locals {
  # Adding a protected app is one entry here, plus the components/oidc component
  # in the app's own kustomization.yaml.
  #
  #   display_name  the tile's label on authentik's user dashboard
  #   hostnames     must match the HTTPRoute's hostnames exactly
  #   namespaces    where the credential Secret is reflected to
  #   groups        allowed in; EMPTY MEANS EVERY AUTHENTICATED USER
  #   sub_mode      claim authentik puts in `sub`; only set when the app makes a
  #                 user record out of it
  #   include_claims_in_id_token
  #                 only for an app that reads the id token itself
  apps = {
    echo = {
      display_name = "Echo"
      description  = "Request echo. Renders the request back as JSON."
      hostnames    = ["echo.${var.domain}"]
      namespaces   = ["default"]
      groups       = ["home-ops"]
    }

    # ── apps that speak OIDC themselves ───────────────────────────────────────
    # No components/oidc here: a gateway-level SecurityPolicy 302s the Immich
    # mobile app's /api/* calls to a login page it cannot render, so Immich runs
    # its own OAuth and the route stays open at the gateway.
    immich = {
      display_name = "Immich"
      description  = "Photo and video library."
      hostnames    = ["immich.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/immich.svg"
      # Read out of tofu-controller by ESO, not reflected - see
      # kubernetes/apps/immich/immich/app/externalsecret-config.yaml.
      namespaces = ["immich"]
      # Its own group, which also carries immich_quota. See groups.tf.
      groups = ["immich"]
      # Immich makes a user record per login, so `sub` has to be readable.
      sub_mode                   = "user_username"
      include_claims_in_id_token = true
      gateway_callback           = false
      extra_redirect_uris = [
        "https://immich.${var.domain}/auth/login",
        "https://immich.${var.domain}/user-settings",
        # The mobile app's custom scheme; it has no host to match on.
        "app.immich:///oauth-callback",
      ]
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
      icon       = "https://duplicacy.com/img/duplicacy.png"
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

    # ── the cluster's own admin UIs ───────────────────────────────────────────
    # Each pairs with the components/oidc component in the app's own tree. All
    # of them stay on envoy-internal, so authentik is the only auth they have -
    # their built-in logins were removed once these existed. rook is the one
    # exception: see its entry.
    flux = {
      display_name = "Flux"
      description  = "GitOps control plane."
      hostnames    = ["flux.${var.domain}"]
      # selfh.st carries no flux mark; this is the CNCF project artwork.
      icon       = "https://raw.githubusercontent.com/cncf/artwork/main/projects/flux/icon/color/flux-icon-color.svg"
      namespaces = ["flux-system"]
      groups     = ["home-ops"]
    }
    # Quoted: an HCL object key cannot carry a hyphen unquoted. The key drives
    # the Secret name, so it must stay equal to ${APP} in the component.
    "garage-webui" = {
      display_name = "Garage"
      description  = "S3 object store administration."
      hostnames    = ["garage.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/garage.svg"
      namespaces   = ["garage"]
      groups       = ["home-ops"]
    }
    kopia = {
      display_name = "Kopia"
      description  = "Backup repository browser."
      hostnames    = ["kopia.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/kopia.svg"
      namespaces   = ["storage"]
      groups       = ["home-ops"]
    }
    # The ceph dashboard keeps its own admin password as break-glass: while its
    # OAuth2 SSO is on, local login is broken, so recovering from an authentik
    # outage means `ceph dashboard sso disable` first.
    rook = {
      display_name = "Ceph"
      description  = "Storage cluster administration."
      hostnames    = ["rook.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/ceph.svg"
      namespaces   = ["rook-ceph"]
      groups       = ["home-ops"]
      # The dashboard creates a user record per login, named after `sub` - a
      # hashed_user_id would be a hex blob in the user list and in the audit log.
      sub_mode = "user_username"
      # It builds a user record out of name and email, and envoy forwards it the
      # ID TOKEN, so those claims have to be in there and not only behind
      # userinfo. Its roles come from the roles_path in the rook-ceph-sso Job.
      include_claims_in_id_token = true
    }
  }

  group_ids = { for k, g in authentik_group.this : k => g.id }
}
