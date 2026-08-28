variable "key" {
  # The provider name, the application slug and the client_id all become
  # "<name_prefix>-<key>". The slug drives the OIDC issuer path, so keeping all
  # three identical means neither this module nor components/oidc has to encode
  # a mapping.
  description = "Short app identifier, matching the home-ops app name."
  type        = string
}

variable "name_prefix" {
  type = string
}

variable "display_name" {
  type = string
}

variable "description" {
  type    = string
  default = ""
}

variable "hostnames" {
  description = "Hostnames the app's HTTPRoute serves."
  type        = list(string)
}

variable "icon" {
  # Empty is passed to authentik as null rather than "", so an app without an
  # icon does not produce a perpetual diff.
  description = "URL of the dashboard tile icon."
  type        = string
  default     = ""
}

variable "open_in_new_tab" {
  # These are all separate admin UIs, so the dashboard should not navigate away
  # from itself.
  description = "Open the app in a new tab from authentik's dashboard."
  type        = bool
  default     = true
}

variable "groups" {
  # Keyed by NAME, not id: the ids are only known after apply, and for_each
  # cannot build a resource graph from unknown keys.
  #
  # authentik treats an application with no policy bindings as open, so an
  # accidentally empty map is a silent widening rather than a lockout.
  description = "Groups allowed in, name => id. EMPTY MEANS EVERY AUTHENTICATED USER."
  type        = map(string)
  default     = {}
}

variable "sub_mode" {
  # Stable across username and e-mail changes, which is what a gateway-level
  # yes/no gate wants. Changing it later orphans existing accounts in that app.
  description = "Claim authentik puts in `sub`."
  type        = string
  default     = "hashed_user_id"
}

variable "secret_namespace" {
  type = string
}

variable "reflect_to" {
  description = "Namespaces reflector may mirror the credential Secret into."
  type        = list(string)
}

variable "authorization_flow" {
  type = string
}

variable "invalidation_flow" {
  type = string
}

variable "property_mappings" {
  type = list(string)
}

variable "include_claims_in_id_token" {
  # Sent explicitly, and the default matches what the provider already sends: the
  # attribute is Optional but NOT Computed, so an unset bool reaches authentik as
  # false rather than as authentik's own default. Only an app that reads the id
  # token itself needs it on - a gateway-only gate never looks inside.
  description = "Put the mapped claims in the id token, not only in userinfo."
  type        = bool
  default     = false
}

variable "signing_key" {
  type = string
}
