resource "authentik_property_mapping_provider_scope" "immich_quota" {
  name        = "${var.name_prefix}-immich-quota"
  scope_name  = "immich_quota"
  description = "Per-user Immich storage quota, in GiB."

  # A quota on the user wins over the immich group's default in groups.tf.
  # Returning no claim rather than 0 when neither is set: 0 means UNLIMITED to
  # Immich, while an absent claim falls back to oauth.defaultStorageQuota.
  #
  # Immich reads this ONLY when it creates the account - changing either
  # attribute later means editing the user in Immich's own admin UI.
  expression = <<-EOT
    quota = request.user.attributes.get(
        "immich_quota",
        request.user.group_attributes().get("immich_quota"),
    )
    if quota is None:
        return {}
    return {"immich_quota": quota}
  EOT
}

resource "authentik_property_mapping_provider_scope" "email_verified_email" {
  name        = "${var.name_prefix}-email-verified"
  scope_name  = "email"
  description = "Email, asserted as verified."

  # Replaces the managed email mapping for apps with email_verified = true in locals.tf.
  expression = <<-EOT
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOT
}

locals {
  # The `grimoire` attribute of the user's highest-ranked group in groups.tf.
  # Picked explicitly rather than through group_attributes(), whose merge order
  # would decide which of two grimoire groups wins.
  grimoire_attributes = <<-EOT
    rank = {"player": 1, "gm": 2, "admin": 3}
    best = None
    for group in request.user.all_groups():
        attrs = group.attributes.get("grimoire")
        if attrs and (best is None or rank[attrs["role"]] > rank[best["role"]]):
            best = attrs
  EOT
}

# Grimoire requests each claim as a scope of the same name, so scope_name and
# the claim key must match OIDC_GROUPS_CLAIM and OIDC_PERMISSIONS_CLAIM.
resource "authentik_property_mapping_provider_scope" "grimoire_role" {
  name        = "${var.name_prefix}-grimoire-role"
  scope_name  = "grimoire_role"
  description = "Grimoire role: player, gm or admin."

  expression = <<-EOT
    ${local.grimoire_attributes}
    if best is None:
        return {}
    return {"grimoire_role": best["role"]}
  EOT
}

resource "authentik_property_mapping_provider_scope" "grimoire_permissions" {
  name        = "${var.name_prefix}-grimoire-permissions"
  scope_name  = "grimoire_permissions"
  description = "Grimoire viewNSFW, campaignAccess and apiKeys flags."

  # A missing claim denies the login outright, admins included.
  expression = <<-EOT
    ${local.grimoire_attributes}
    if best is None:
        return {}
    return {"grimoire_permissions": best["permissions"]}
  EOT
}
