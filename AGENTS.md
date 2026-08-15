# AGENTS.md

Welcome to the `fog` home lab repository.

## Project Overview
This repository contains Infrastructure as Code (IaC) configuration for setting up and managing a home lab environment consisting of Proxmox VE, Docker hosts, and a Kubernetes cluster.

## Rules & Guidelines
1. **Secrets Management (Zero-Plaintext Protocols)**:
   - **Zero Plaintext Transmission**: Never send, paste, or echo credentials, tokens, passwords, or private keys over `gc mail`, git commits, task beads, or chat output.
   - **Path-Only References**: Always reference secrets by `pass` path, Vault path, target alias, or RAM cache file (`/dev/shm/fog/*-secret.env`).
   - **No Inline Secret Arguments**: Never pass tokens/passwords as CLI arguments (`docker login -p`, `curl -u`). Use `--password-stdin` or `keeper exec`.
   - Use `pass` (password-store) to manage host-level and bootstrap secrets.
   - Use cache files in `/dev/shm/fog/*-secret.env` for active shell sessions to avoid tapping the YubiKey repeatedly. Source public configs via `config.env` and load target secret environments (e.g., `source /dev/shm/fog/proxmox-secret.env`). Use `keeper <target>` (or `keeper --all`) to populate/refresh the secrets cache from `pass`.
   - Use HashiCorp Vault (`https://10.7.82.90:8200`) as the centralized runtime secrets store for Kubernetes.
   - Manage all Vault policies, authentication backends, and role bindings declaratively in Terraform (`provision/vault_config.tf`).
   - Use the External Secrets Operator (ESO) via `ExternalSecret` manifests to sync secrets from Vault into K8s namespaces. Avoid writing static secrets in Git.
   - If Vault is restarted, manually unseal it using [bin/unseal-vault.sh](bin/unseal-vault.sh) (which prompts for YubiKey taps to fetch unseal keys from `pass`).
   - **Do not** attempt to extract, decode, or display sensitive secrets or tokens from the cluster (e.g. running `kubectl get secret -o jsonpath="..." | base64 --decode`).

2. **Infrastructure as Code (IaC)**:
   - Prefer declarative structures (Terraform, Ansible, Kubernetes YAML, Docker Compose).
3. **Cluster & Talos Management**:
   - All VM provisioning and Talos configuration management must live in the `provision/` directory.
   - Always configure Talos Linux nodes to use **UEFI (`ovmf` bios)** and allocate an **EFI Disk** (`efi_disk` block) in the Proxmox VM resource configuration.
   - Assign static IPs and explicitly define default routes (`0.0.0.0/0`) and nameservers in the Talos configurations to ensure clock synchronization (`etcd` and `kubelet` require synchronized time).
   - Ensure `kubeconfig`, `talosconfig`, and intermediate `.yaml` configuration files are never committed to Git (validate they are git-ignored).
4. **Directory Layout & GitOps Guidelines**:
   - **`provision/`**: Contains only Terraform and Talos VM/Node level provisioning files.
   - **`infrastructure/`**: Contains shared Kubernetes platform operators/controllers (e.g., `cert-manager`, `ingress-nginx`, `external-dns`, `vault-integration`).
   - **`apps/`**: Contains user-facing application deployments (e.g., `gitea`, `capacitor`).
   - **`clusters/`**: Contains only the core FluxCD GitOps entrypoint configurations. Do not put application manifests directly inside `clusters/`—instead, reference paths under `infrastructure/` or `apps/` using Flux Kustomizations.
5. **Scope Boundaries**:
   - Only make changes to the `fog` homelab repository, cluster infrastructure, and Proxmox VMs.
   - **Never** attempt to modify the local workstation host (`brida`) or edit system files on the host machine (e.g., `/etc/hosts` or host system configs).
6. **GPU & AI Inference Host Management (`haze` / GX10)**:
   - LLM inference runtimes (e.g., vLLM, Ollama) and GPU server workloads have long startup/warmup lifecycles (loading large models into VRAM, allocating KV cache, and compiling attention kernels).
   - **Never** restart, remove, or recreate GPU model containers, Docker daemons, or systemd services on inference nodes (such as `haze`) to experiment or debug without explicit confirmation from the human operator.
   - Always allow running model containers to complete their initialization and warmup cycles uninterrupted. Use read-only log inspection (`docker logs`) and process monitoring (`ps aux`, `nvidia-smi`) to track progress.



