locals {
  name = "${var.name_prefix}-${var.key}"

  # Static at plan time, since these are names rather than ids.
  group_order = sort(keys(var.groups))

  # Envoy Gateway posts the authorization code back to <redirectURL>, which
  # components/oidc pins to https://<host>/oauth2/callback. authentik rejects the
  # exchange on a byte-level mismatch, so the list is generated from the same
  # hostnames rather than typed out twice.
  #
  # matching_mode strict, never regex: every host is known at plan time, and a
  # regex entry here is an open redirect.
  # An app doing OIDC itself, rather than through the gateway, posts back to its
  # own paths - and a mobile client to a custom scheme, which has no host at
  # all. Those apps set gateway_callback = false and list their own.
  gateway_redirect_uris = var.gateway_callback ? [
    for host in var.hostnames : {
      matching_mode = "strict"
      url           = "https://${host}/oauth2/callback"
    }
  ] : []

  redirect_uris = concat(local.gateway_redirect_uris, [
    for url in var.extra_redirect_uris : {
      matching_mode = "strict"
      url           = url
    }
  ])
}

resource "authentik_provider_oauth2" "this" {
  name      = local.name
  client_id = local.name

  # client_secret deliberately unset: authentik generates it, and it reaches the
  # cluster through kubernetes_secret below. Pinning it would make git the
  # source of truth for a live credential.
  client_type = "confidential"

  # Must be set explicitly. The provider documents grant_types as optional and
  # "Generated", but it sends an empty list and authentik stores it empty, which
  # makes every authorize request fail with invalid_request / "The request is
  # otherwise malformed". refresh_token is what makes offline_access usable.
  #
  # client_credentials is opt-in per app rather than on everywhere: authentik
  # refuses an unconfigured grant outright (grant_type_not_configured), and that
  # refusal is the only thing stopping any user's app password from minting a
  # bearer token for any app they can already open in a browser.
  grant_types = concat(
    ["authorization_code", "refresh_token"],
    var.client_credentials ? ["client_credentials"] : [],
  )

  authorization_flow = var.authorization_flow
  invalidation_flow  = var.invalidation_flow

  property_mappings          = concat(var.property_mappings, var.extra_property_mappings)
  signing_key                = var.signing_key
  sub_mode                   = var.sub_mode
  include_claims_in_id_token = var.include_claims_in_id_token

  allowed_redirect_uris = local.redirect_uris
}

resource "authentik_application" "this" {
  name              = var.display_name
  slug              = local.name
  protocol_provider = authentik_provider_oauth2.this.id
  meta_description  = var.description
  meta_launch_url   = "https://${var.hostnames[0]}"
  meta_icon         = var.icon != "" ? var.icon : null
  open_in_new_tab   = var.open_in_new_tab

  # The dashboard heading this tile sits under. NOT access control - that is
  # authentik_policy_binding below.
  group = var.name_prefix

  # A user in ANY bound group gets in. "all" would demand membership in every
  # bound group at once.
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "group" {
  # Keyed by group NAME. Keying by id fails at plan time on a first apply -
  # authentik_group.id is unknown until apply, and for_each keys must be known.
  for_each = var.groups

  target = authentik_application.this.uuid
  group  = each.value
  # authentik keys bindings on (target, order), so each needs a distinct one.
  # Derived from the sorted names, so it does not shift when a group is added.
  order = index(local.group_order, each.key)
}

# Deliberately the deprecated unversioned name. Provider 3.x wants
# kubernetes_secret_v1, but a `moved` block across resource types needs the
# provider to implement MoveResourceState, and this one does not - the plan
# fails outright. Renaming without `moved` would recreate the secret with a
# fresh client_secret and break every login. The deprecation is a warning only.
resource "kubernetes_secret" "oidc" {
  metadata {
    name      = "${var.key}-oidc"
    namespace = var.secret_namespace
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"            = "true"
      "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = join(",", var.reflect_to)
    }
  }

  # Key names are fixed by Envoy Gateway, not chosen: clientIDRef reads
  # `client-id` and clientSecret reads `client-secret`.
  data = {
    client-id     = authentik_provider_oauth2.this.client_id
    client-secret = authentik_provider_oauth2.this.client_secret
  }

  type = "Opaque"
}
