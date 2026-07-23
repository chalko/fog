# Tailscale & LiteLLM Tier Integration

This document outlines the setup, architecture, and credential routing for **Tailscale** and **LiteLLM Tiers** on the `fog` cluster.

---

## 1. Tailscale Kubernetes Operator

The official Tailscale Kubernetes Operator is installed in the `tailscale` namespace. It coordinates ingress, egress, and service exposure directly to your Tailnet.

### Repository Layout
*   **[namespace.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/namespace.yaml)**: Declares the `tailscale` namespace.
*   **[secrets.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/secrets.yaml)**: ExternalSecret definition syncing Vault OAuth credentials.
*   **[tailscale-operator.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/tailscale-operator.yaml)**: HelmRepository and HelmRelease configurations.
*   **[kustomization.yaml](file:///home/nick/src/fog/infrastructure/base/tailscale-operator/kustomization.yaml)**: Bundles the operator manifests.

### Authentication & Secrets flow
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

---

## 2. LiteLLM Tier Routing & Virtual Keys

LiteLLM routes queries to different backend models based on three logical tiers.

### The Three Tiers
*   **Utility Tier (`utility-tier`)**: Maps to local CPU-only Ollama (`llama3.2:1b`) serving fast, low-cost utility tasks.
*   **Worker Tier (`worker-tier`)**: Maps to a remote GPU node serving code generation models (`qwen2.5-coder-32b` or similar) over a secure Tailscale link.
*   **Executive Tier (`executive-tier`)**: Maps to frontier API models (`gemini-1.5-pro` and `grok-2`).

### Codifying Virtual Keys (GitOps)
Instead of manual key creation, a Kubernetes bootstrap Job (`apps/base/litellm/bootstrap-job.yaml`) runs on startup to guarantee the following keys exist:

1.  **Gas Town Workers (`gastown-workers`)**: Scoped to the `utility-tier` and `worker-tier`.
2.  **Hermes/Mayor (`hermes-mayor`)**: Scoped to the `executive-tier`, `worker-tier`, and `utility-tier`.

The job runs a curl bootstrap script mounted from `bootstrap-configmap.yaml`, pulling the `LITELLM_MASTER_KEY` securely from the cluster secrets.
