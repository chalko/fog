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
