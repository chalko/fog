# Tailscale Kubernetes Operator

This document outlines the setup, architecture, and credential routing for the **Tailscale Kubernetes Operator** on the `fog` cluster.

---

## 1. Operator Installation

The official Tailscale Kubernetes Operator is installed in the `tailscale` namespace. It coordinates ingress, egress, and service exposure directly to your Tailnet.

### Repository Layout
*   **[namespace.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/namespace.yaml)**: Declares the `tailscale` namespace.
*   **[secrets.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/secrets.yaml)**: ExternalSecret definition syncing Vault OAuth credentials.
*   **[tailscale-operator.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/tailscale-operator.yaml)**: HelmRepository and HelmRelease configurations.
*   **[kustomization.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/kustomization.yaml)**: Bundles the operator manifests.

### Authentication & Secrets Flow
1.  **OAuth Client**: Generated in the Tailscale Admin Console with scopes:
    *   `Devices > Core` (Read & Write)
    *   `Keys > Auth Keys` (Read & Write)
    *   `General > Services` (Read & Write)
    *   *Default Tag*: `tag:k8s-operator`
2.  **Vault Storage**: Stored at path `secret/infrastructure/tailscale` with keys:
    *   `client_id`
    *   `client_secret`
3.  **K8s Sync**: ExternalSecrets retrieves these values and provisions the `operator-oauth` secret in the `tailscale` namespace.
4.  **Vault Policy**: Supported by the `k8s-read` policy (defined in `provision/vault_config.tf` and applied via Terraform), allowing read capabilities on `secret/data/infrastructure/*`.
