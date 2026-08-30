# The `immich` group in groups.tf carries immich_quota; turning it into an OIDC
# claim needs a scope mapping, and this token CANNOT create one -
# POST /api/v3/propertymappings/provider/scope/ is 403, and a failed apply
# blocks every Kustomization behind authentik-oidc. So the mapping is created by
# hand in authentik, once, and only read here:
#
#   name        home-ops-immich-quota
#   scope name  immich_quota
#   expression  return {"immich_quota": request.user.group_attributes().get("immich_quota", 0)}
#
# Until it exists, immich_quota_scope stays false and Immich falls back to the
# defaultStorageQuota in its own config, which is the same 50 GiB. Flipping the
# variable also means adding immich_quota to `oauth.scope` in
# kubernetes/apps/immich/immich/app/externalsecret-config.yaml - authentik
# rejects the authorize request for a scope with no mapping behind it.
data "authentik_property_mapping_provider_scope" "immich_quota" {
  count = var.immich_quota_scope ? 1 : 0

  name = "${var.name_prefix}-immich-quota"
}
