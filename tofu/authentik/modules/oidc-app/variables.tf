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

variable "signing_key" {
  type = string
}
