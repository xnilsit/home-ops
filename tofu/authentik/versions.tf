terraform {
  required_version = ">= 1.9.0"

  required_providers {
    authentik = {
      source = "goauthentik/authentik"
      # renovate: datasource=terraform-provider depName=goauthentik/authentik
      version = "2026.5.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }

  # No backend block: tofu-controller injects one from
  # Terraform.spec.backendConfig.customConfiguration.
}
