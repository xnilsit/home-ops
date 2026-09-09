apiVersion: v1alpha1
kind: UnattendedInstallConfig
provisioning:
  diskSelector:
    match: '"{{ .Node.Data.installDisk }}" in disk.symlinks'
