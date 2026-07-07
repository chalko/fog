# fog

Home lab Infrastructure as Code (IaC) configuration tracking repo for Proxmox VE, Docker, and Kubernetes (K8s).

## Repository Structure

- `bin/`: Utility scripts (e.g., environment loader)
- `proxmox/`: Proxmox IaC configurations (Terraform/OpenTofu, Ansible, etc.)
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
