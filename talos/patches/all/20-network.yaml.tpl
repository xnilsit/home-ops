---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: ethSel0
selector:
  match: glob("{{ .Node.Data.macAddr }}", mac(link.permanent_addr))
---
# routePriority is required on an aliased link, siderolabs/talos#12738
apiVersion: v1alpha1
kind: LinkConfig
name: ethSel0
up: true
mtu: {{ .Node.Data.mtu }}
addresses:
  - address: "{{ .Node.Data.ipv4 }}"
    routePriority: 1024
  - address: "{{ .Node.Data.ipv6 }}/64"
    routePriority: 1024
routes:
  - gateway: "{{ .Data.gateway }}"
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
name: "{{ .Data.vip }}"
link: ethSel0
