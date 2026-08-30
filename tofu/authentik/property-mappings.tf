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
