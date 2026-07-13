# AGENTS.md

Welcome to the `fog` home lab repository.

## Project Overview
This repository contains Infrastructure as Code (IaC) configuration for setting up and managing a home lab environment consisting of Proxmox VE, Docker hosts, and a Kubernetes cluster.

## Rules & Guidelines
1. **Secrets Management**:
   - Never commit plaintext secrets to this repository.
   - Use `pass` (password-store) to manage host-level and bootstrap secrets.
   - Use cache files in `/dev/shm/fog/*.env` for active shell sessions to avoid tapping the YubiKey repeatedly.
   - Use HashiCorp Vault (`https://10.7.82.90:8200`) as the centralized runtime secrets store for Kubernetes.
   - Manage all Vault policies, authentication backends, and role bindings declaratively in Terraform (`cluster/vault_config.tf`).
   - Use the External Secrets Operator (ESO) via `ExternalSecret` manifests to sync secrets from Vault into K8s namespaces. Avoid writing static secrets in Git.
   - If Vault is restarted, manually unseal it using the unseal keys stored in `pass`.
2. **Infrastructure as Code (IaC)**:
   - Prefer declarative structures (Terraform, Ansible, Kubernetes YAML, Docker Compose).
3. **Cluster & Talos Management**:
   - All VM provisioning and Talos configuration management must live in the `cluster/` directory.
   - Always configure Talos Linux nodes to use **UEFI (`ovmf` bios)** and allocate an **EFI Disk** (`efi_disk` block) in the Proxmox VM resource configuration.
   - Assign static IPs and explicitly define default routes (`0.0.0.0/0`) and nameservers in the Talos configurations to ensure clock synchronization (`etcd` and `kubelet` require synchronized time).
   - Ensure `kubeconfig`, `talosconfig`, and intermediate `.yaml` configuration files are never committed to Git (validate they are git-ignored).

