locals {
  groups = ["home-ops"]
}

resource "authentik_group" "this" {
  for_each = toset(local.groups)

  name = each.value

  # `users` deliberately unset. It is Optional+Computed, so membership stays
  # whatever the UI or an LDAP source set, and an apply never empties it.
}
