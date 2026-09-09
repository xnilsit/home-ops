# Talos Patching

Machine configs are assembled by [topf](https://postfinance.github.io/topf/) from
`../topf.yaml` plus the strategic merge patches in this directory.

<https://www.talos.dev/latest/talos-guides/configuration/patching/>

## Patch Directories

Patches merge in this order, alphabetically within each directory, with later
patches taking precedence:

- `all/`: applied to every node
- `control-plane/`: applied to control-plane nodes
- `worker/`: applied to worker nodes
- `node/${hostname}/`: applied to the node with the specified name

Files ending in `.yaml.tpl` are Go-templated per node; see the
[topf configuration model](https://postfinance.github.io/topf/main/configuration-model/)
for the available template variables. A `.tpl` file is parsed in full, YAML
comments included, so a literal `{{` in a comment breaks the render.

Patches are Talos 1.14 multi-document configs. JSON patches (RFC 6902) are not
supported; use `$patch: delete` for removals.
