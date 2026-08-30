variable "authentik_url" {
  # No default: the hostname is not committed in the clear. It arrives as
  # ${AUTHENTIK_URL} from cluster-secrets, the same way manifests get domains.
  description = "Base URL of the authentik running in the other cluster."
  type        = string
}

variable "authentik_token" {
  description = "Service-account API token, from Secret authentik-tofu."
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Public DNS domain the protected hostnames live under."
  type        = string
}

variable "secret_namespace" {
  description = "Namespace the per-app credential Secrets are written to."
  type        = string
}

variable "name_prefix" {
  # authentik Provider.name is unique across ALL providers, and this instance is
  # shared with the other cluster's own applications.
  description = "Prefix keeping home-ops objects clear of the other cluster's."
  type        = string
  default     = "home-ops"
}
