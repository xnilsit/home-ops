locals {
  # Adding a protected app is one entry here, plus the components/oidc component
  # in the app's own kustomization.yaml.
  #
  #   display_name  the tile's label on authentik's user dashboard
  #   hostnames     must match the HTTPRoute's hostnames exactly
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

    trek = {
      display_name = "TREK"
      description  = "Travel planner."
      hostnames    = ["trek.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/trek.svg"
      # Its own groups, so travel companions get in without being handed the
      # cluster's admin UIs. trek-admin is also what OIDC_ADMIN_VALUE matches.
      groups = ["trek", "trek-admin"]
      # TREK makes a user record per login and reads the id token itself.
      sub_mode                   = "user_username"
      include_claims_in_id_token = true
      gateway_callback           = false
      extra_redirect_uris = [
        "https://trek.${var.domain}/api/auth/oidc/callback",
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
      icon   = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/visual-studio-code.svg"
      groups = ["home-ops"]
    }
    duplicacy = {
      display_name = "Duplicacy"
      description  = "Backup console."
      hostnames    = ["backup.${var.domain}"]
      # Vendor logo: selfh.st has duplicati, a different product.
      icon   = "https://duplicacy.com/img/duplicacy.png"
      groups = ["home-ops"]
    }
    oni = {
      display_name = "Oni"
      hostnames    = ["oni.${var.domain}"]
      # 192.168.0.200:5000 is Synology DSM.
      icon   = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/synology.svg"
      groups = ["home-ops"]
    }
    openspeedtest = {
      display_name = "OpenSpeedTest"
      hostnames    = ["ost.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/openspeedtest.svg"
      groups       = ["home-ops"]
    }
    scrutiny = {
      display_name = "Scrutiny"
      description  = "Disk SMART monitoring."
      hostnames    = ["scrutiny.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/scrutiny.svg"
      groups       = ["home-ops"]
    }
    unbalanced = {
      display_name = "Unbalanced"
      hostnames    = ["unbalanced.${var.domain}"]
      # An Unraid plugin, so it borrows the Unraid mark.
      icon   = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/unraid.svg"
      groups = ["home-ops"]
    }
    unraid = {
      display_name = "Unraid"
      description  = "NAS administration."
      hostnames    = ["unraid.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/unraid.svg"
      groups       = ["home-ops"]
    }

    gatus = {
      display_name = "Gatus"
      description  = "Uptime and status dashboard."
      hostnames    = ["gatus.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/gatus.svg"
      groups       = ["home-ops"]
    }

    # Not a UI: the identity gatus probes WITH, as opposed to the one above,
    # which is how a human reaches the dashboard. A separate provider because
    # authentik scopes iss and aud per provider, and every protected app's
    # SecurityPolicy trusts exactly this one - so a token minted here opens all
    # of them, and nothing else may be able to mint one.
    #
    # No browser flow ever runs against it, so no redirect URIs.
    #
    # groups is deliberately EMPTY, the one place where the warning on the
    # module's `groups` variable is the intent rather than an accident. The
    # identity is the home-ops-gatus-probe service account, whose app password
    # is held in SOPS beside the app; with no bindings the token request passes
    # on AppAccessWithoutBindings and that password is the whole gate. Binding a
    # group instead would mean a data lookup of an account terraform does not
    # own, and would break the moment it is recreated.
    #
    # The service account itself is NOT managed here: authentik's token API
    # forces a new token onto the calling user unless that caller is a superuser
    # (core/api/tokens.py, perform_create) and then refuses any later change of
    # owner, so `authentik_token` cannot mint one for somebody else. It is
    # created once through POST /core/users/service_account/, which writes the
    # Token through the ORM and takes expiring: false.
    #
    # The client_id half still comes from this provider, and its client_secret,
    # written to the gatus-probe-oidc Secret by the module, is deliberately left
    # unused - presenting it would work too, but it would authenticate as an
    # account authentik generates rather than as a named one.
    #
    # Quoted: an HCL object key cannot carry a hyphen unquoted.
    "gatus-probe" = {
      display_name       = "Gatus probe"
      description        = "Machine identity the uptime probes authenticate with."
      hostnames          = ["gatus.${var.domain}"]
      groups             = []
      gateway_callback   = false
      client_credentials = true
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
      icon   = "https://raw.githubusercontent.com/cncf/artwork/main/projects/flux/icon/color/flux-icon-color.svg"
      groups = ["home-ops"]
    }
    # Quoted: an HCL object key cannot carry a hyphen unquoted. The key drives
    # the Secret name, so it must stay equal to ${APP} in the component.
    "garage-webui" = {
      display_name = "Garage"
      description  = "S3 object store administration."
      hostnames    = ["garage.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/garage.svg"
      groups       = ["home-ops"]
    }
    kopia = {
      display_name = "Kopia"
      description  = "Backup repository browser."
      hostnames    = ["kopia.${var.domain}"]
      icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/kopia.svg"
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
