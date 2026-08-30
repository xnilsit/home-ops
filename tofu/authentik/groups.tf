locals {
  # name => attributes. The keys are what toset() produced before, so switching
  # from a list is an in-place change rather than a replacement.
  groups = {
    "home-ops" = {}
    # Read by the immich_quota scope mapping in property-mappings.tf.
    # GiB, which is the unit Immich's storage quota claim expects.
    "immich" = { immich_quota = 50 }
  }
}

resource "authentik_group" "this" {
  for_each = local.groups

  name       = each.key
  attributes = length(each.value) > 0 ? jsonencode(each.value) : null

  # `users` deliberately unset. It is Optional+Computed, so membership stays
  # whatever the UI or an LDAP source set, and an apply never empties it.
}
