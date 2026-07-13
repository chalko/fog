# fog

Home lab Infrastructure as Code (IaC) configuration tracking repo for Proxmox VE, Docker, and Kubernetes (K8s).

## Repository Structure

- `bin/`: Utility scripts (e.g., environment loader)
- `cluster/`: Declarative cluster infrastructure (Terraform provisioning Proxmox VMs and bootstrapping Talos Linux K8s nodes)
- `docker/`: Docker Compose configurations and container definitions
- `k8s/`: Kubernetes manifests, Helm values, and GitOps configurations


## Secrets Management

Secrets are managed using `pass` (password-store) and cached locally in `/dev/shm/fog/*.env` to avoid prompting for YubiKey authentication/passphrase entry repeatedly during a session.

### Usage

To fetch and cache your environment variables:

```bash
source bin/load-env.sh
```

This will:
1. Verify/create directory `/dev/shm/fog` with `700` permissions.
2. Read required secrets from `pass` (e.g., `fog/proxmox/api_token_secret`, etc.).
3. Cache them securely under `/dev/shm/fog/{proxmox,docker,k8s}.env` with `600` permissions.
4. Source the files in the current shell session.

## Cluster Deployment & Management

The Kubernetes cluster is managed entirely using Terraform/OpenTofu inside the `cluster/` directory.

### Quick Start
1. Fetch and load credentials into your shell:
   ```bash
   source bin/load-env.sh
   ```
2. Navigate to the cluster directory, initialize, and deploy:
   ```bash
   cd cluster
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

