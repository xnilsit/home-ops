# The ceph dashboard takes its dashboard roles from a claim in the token and
# maps the strings in its ROLE_MAPPER - administrator, read-only, rbd, rgw, ... -
# onto its built-in roles. None of authentik's default mappings emit them, and
# with no roles at all get_user_roles() answers 403, so the claim has to come
# from a mapping of our own.
#
# Unlike everything else in data.tf this is created rather than read. It is
# bound to the rook provider only (locals.tf, extra_property_mappings), and its
# scope has to be requested as well - see the SecurityPolicy patch in
# kubernetes/apps/rook-ceph/rook-ceph/oidc.
resource "authentik_property_mapping_provider_scope" "ceph_roles" {
  name       = "${var.name_prefix}-ceph-roles"
  scope_name = "ceph_roles"
  # Membership is already what authentik's policy binding gates on, so this is
  # the same yes/no expressed as the role the dashboard understands.
  expression = <<-EOT
    return {
        "roles": ["administrator"] if ak_is_group_member(
            request.user, name="${authentik_group.this["home-ops"].name}") else [],
    }
  EOT
}
