# LiteLLM Tier Routing & Virtual Keys

This document outlines the setup, architecture, and virtual key management for the **LiteLLM Tiers** on the `fog` cluster.

---

## 1. Logical Model Tiers

LiteLLM routes queries to different backend models based on three logical tiers configured in [configmap.yaml](file:///home/nick/src/fog/apps/base/litellm/configmap.yaml):

*   **Utility Tier (`utility-tier`)**: Maps to local CPU-only Ollama (`llama3.2:1b`) serving fast, low-cost utility tasks.
*   **Worker Tier (`worker-tier`)**: Maps to a remote GPU node serving code generation models (`qwen2.5-coder-32b` or similar) over a secure Tailscale link.
*   **Executive Tier (`executive-tier`)**: Maps to frontier API models (`gemini-1.5-pro` and `grok-2`).

---

## 2. Codifying Virtual Keys (GitOps Integration)

Instead of manual key creation, a Kubernetes bootstrap Job (`apps/base/litellm/bootstrap-job.yaml`) runs on startup to guarantee the following keys exist:

1.  **Gas Town Workers (`gastown-workers`)**: Scoped to the `utility-tier` and `worker-tier`.
2.  **Hermes/Mayor (`hermes-mayor`)**: Scoped to the `executive-tier`, `worker-tier`, and `utility-tier`.

The job runs a curl bootstrap script mounted from `bootstrap-configmap.yaml`, pulling the `LITELLM_MASTER_KEY` securely from the cluster secrets.
