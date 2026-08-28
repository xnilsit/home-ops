module "app" {
  source   = "./modules/oidc-app"
  for_each = local.apps

  key          = each.key
  name_prefix  = var.name_prefix
  display_name = each.value.display_name
  description  = try(each.value.description, "")
  hostnames    = each.value.hostnames
  sub_mode     = try(each.value.sub_mode, "hashed_user_id")
  icon         = try(each.value.icon, "")

  # Name to id via groups.tf, so a typo in locals.tf fails at plan time rather
  # than producing an application nobody can reach. Keyed by name, because the
  # ids are unknown until apply and for_each keys must be known at plan time.
  groups = { for g in try(each.value.groups, []) : g => local.group_ids[g] }

  secret_namespace   = var.secret_namespace
  reflect_to         = each.value.namespaces
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
  property_mappings  = data.authentik_property_mapping_provider_scope.oidc.ids
  signing_key        = data.authentik_certificate_key_pair.signing.id

  include_claims_in_id_token = try(each.value.include_claims_in_id_token, false)
}
