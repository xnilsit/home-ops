locals {
  # name => attributes. The keys are what toset() produced before, so switching
  # from a list is an in-place change rather than a replacement.
  groups = {
    "home-ops" = {}
    # The DEFAULT quota, in GiB, which is the unit Immich's claim expects. An
    # immich_quota attribute on a user overrides it - see property-mappings.tf.
    "immich" = { immich_quota = 50 }
    # Access to TREK, and separately the group TREK maps to its admin role via
    # OIDC_ADMIN_VALUE. Both are bound to the application, so either one alone
    # gets a user in.
    "trek"       = {}
    "trek-admin" = {}
  }
}

resource "authentik_group" "this" {
  for_each = local.groups

  name       = each.key
  attributes = length(each.value) > 0 ? jsonencode(each.value) : null

  # `users` deliberately unset. It is Optional+Computed, so membership stays
  # whatever the UI or an LDAP source set, and an apply never empties it.
}
