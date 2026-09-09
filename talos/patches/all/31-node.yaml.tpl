apiVersion: v1alpha1
kind: KubeNodeConfig
# IPv4 first: kubelet orders a pod's IPs to match the node's, and a pod
# whose primary IP is IPv6 fails any probe against a 0.0.0.0-only listener.
# /128, not the LAN /64: SLAAC also puts a ULA on this interface and either
# would match, leaving the published node IP up to address ordering.
nodeIP:
  validSubnets:
    - "{{ .Data.nodeCIDRv4 }}"
    - "{{ .Node.Data.ipv6 }}/128"
