# Home Lab Planning & Architecture

This directory tracks decisions, architectures, and implementation steps for bootstrapping and managing the home lab.

## Planned Architectures

1. **Proxmox VE Setup**:
   - Provisioning Virtual Machines (VMs) and Containers (LXCs) declaratively (e.g., via Terraform/OpenTofu).
2. **Docker Hosts**:
   - Defining multi-container stacks using Docker Compose.
3. **Kubernetes Cluster**:
   - Local cluster setup (e.g., Talos Linux, K3s, or kubeadm).
   - Deployment tracking via GitOps (e.g., FluxCD or ArgoCD).

## Completed Plans

All completed milestones and bootstrap documentation are moved to [plans/completed/](file:///home/nick/src/fog/plans/completed):

- [bootstrap_slim.md](file:///home/nick/src/fog/plans/completed/bootstrap_slim.md) - Initial bootstrapping and naming conventions for the Minisforum host.
- [add_samsung_nvme.md](file:///home/nick/src/fog/plans/completed/add_samsung_nvme.md) - Adding Samsung NVMe SSD to Proxmox VE host using LVM-Thin.
- [resize_k8s_nodes.md](file:///home/nick/src/fog/plans/completed/resize_k8s_nodes.md) - Storage migration to ZFS and VM resource resizing.
- [vault_bootstrap.md](file:///home/nick/src/fog/plans/completed/vault_bootstrap.md) - Installation and configuration of HashiCorp Vault with K8s authentication backend.
- [proxmox_dns_sync.md](file:///home/nick/src/fog/plans/completed/proxmox_dns_sync.md) - Design and Helm deployment details for DNS syncing between PVE and Pi-hole.
- [flux_bootstrap.md](file:///home/nick/src/fog/plans/completed/flux_bootstrap.md) - Deploying FluxCD to automate K8s cluster GitOps tracking using self-hosted Gitea.
- [cert_manager_install.md](file:///home/nick/src/fog/plans/completed/cert_manager_install.md) - Deploying Cert-Manager and configuring the DNS-01 Let's Encrypt challenge.
- [gitea_install.md](file:///home/nick/src/fog/plans/completed/gitea_install.md) - HelmRelease deployment of Gitea integrated with Vault secrets.


