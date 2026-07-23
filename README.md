# fog

Home lab Infrastructure as Code (IaC) configuration tracking repo for Proxmox VE, Docker, and Kubernetes (K8s).

## Repository Structure

- `bin/`: Utility scripts (e.g., environment loader)
- `provision/`: Declarative cluster infrastructure (Terraform provisioning Proxmox VMs and bootstrapping Talos Linux K8s nodes)
- `docker/`: Docker Compose configurations and container definitions
- `docs/`: Design documentation, hardware inventory, and system setup guides (e.g., [docs/vault.md](file:///home/nick/src/fog/docs/vault.md))
- `infrastructure/`: Shared platform components (e.g., cert-manager, ingress-nginx, external-dns, external-secrets)
- `apps/`: User-facing application deployments (e.g., gitea, capacitor)



## Secrets Management

Secrets are managed in a split model:
1. **Bootstrap/Host Secrets**: Stored in `pass` (password-store) and cached locally in `/dev/shm/fog/*.env` for active shell sessions to avoid repeating YubiKey taps.
2. **Kubernetes Runtime Secrets**: Stored in **HashiCorp Vault** (`https://10.7.82.90:8200`) and dynamically synced into pods using the **External Secrets Operator**.

### Bootstrap Secrets Setup

To fetch and cache your environment variables:

```bash
source bin/load-env.sh
```

This will:
1. Verify/create directory `/dev/shm/fog` with `700` permissions.
2. Read required secrets from `pass` (e.g., `fog/proxmox/api_token_secret`, etc.).
3. Cache them securely under `/dev/shm/fog/{proxmox,docker,k8s}.env` with `600` permissions.
4. Source the files in the current shell session (which exports credentials like `VAULT_TOKEN`).

## Cluster Deployment & Management

The Kubernetes cluster is managed entirely using Terraform/OpenTofu inside the `provision/` directory.

### Quick Start
1. Fetch and load credentials into your shell:
   ```bash
   source bin/load-env.sh
   ```
2. Navigate to the cluster directory, initialize, and deploy:
   ```bash
   cd provision
   terraform init
   terraform apply
   ```

This will automatically:
- Provision the VMs on the Proxmox host.
- Generate and securely apply Talos Linux machine configurations.
- Bootstrap the Kubernetes cluster.
- Retrieve and save `kubeconfig` and `talosconfig` to the root of the repository (both are git-ignored).

### Interacting with the Cluster
Once deployed, you can access the cluster using `kubectl` or `talosctl` from the root directory:
```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

## Reference & Documentation

For detailed information on design decisions, hardware setups, and operation procedures:

- **Hardware Specifications**: See [docs/hardware.md](file:///home/nick/src/fog/docs/hardware.md) for details on the host node (`misty`).
- **Secrets & Integration**: See [docs/vault.md](file:///home/nick/src/fog/docs/vault.md) for Vault setup, unsealing steps, and Kubernetes External Secrets configurations.
- **Environment Management**: See [bin/load-env.sh](file:///home/nick/src/fog/bin/load-env.sh) for credential caching setup.
- **Tailscale & LiteLLM Integration**: See [docs/tailscale.md](file:///home/nick/src/fog/docs/tailscale.md) for details on the Tailscale Kubernetes Operator and LiteLLM virtual key tiers.
- **Completed Infrastructure Milestones**: See [plans/completed/](file:///home/nick/src/fog/plans/completed) for historical blueprints (e.g., node sizing, DNS integration, and disk expansions).


