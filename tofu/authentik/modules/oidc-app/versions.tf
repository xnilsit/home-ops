terraform {
  # Required in the child module too: without it tofu infers the source from the
  # resource prefix and looks for hashicorp/authentik, which does not exist.
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
