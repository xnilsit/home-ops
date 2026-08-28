provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}

# Empty on purpose. The provider detects KUBERNETES_SERVICE_HOST/PORT and uses
# the runner pod's ServiceAccount. Passing host plus file() of the token would
# break `tofu validate` anywhere outside a pod, since file() is read at
# validate time.
provider "kubernetes" {}
