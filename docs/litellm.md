# LiteLLM Tier Routing & Virtual Keys

This document outlines the setup, architecture, and virtual key management for the **LiteLLM Tiers** on the `fog` cluster.

---

## 1. Logical Model Tiers

LiteLLM routes queries to different backend models based on three logical tiers configured in [configmap.yaml](file:///home/nick/src/fog/apps/base/litellm/configmap.yaml):

*   **Utility Tier (`utility-tier`)**: Maps to local CPU-only Ollama (`llama3.2:1b`) serving fast, low-cost utility tasks.
*   **Worker Tier (`worker-tier`)**: Maps to an on-demand RunPod Secure Cloud GPU node hosting `vLLM` (e.g., serving `Qwen3-8B` or coder models).
*   **Executive Tier (`executive-tier`)**: Maps to frontier API models (`gemini-1.5-pro`/`gemini-3.1-pro` and `grok-2`).

---

## 2. Secrets Management & Vault Integration

The LiteLLM deployment mounts secrets directly from Vault via the External Secrets Operator (`apps/base/litellm/secrets.yaml`). 

*   `gemini_api_key` and `xai_api_key`: Used for the Executive Tier.
*   `master_key`: Used for generating virtual keys (Hermes/Gas Town).
*   `vllm_api_key`: Used for the Worker Tier to authenticate against the remote RunPod endpoint. This key is injected as `VLLM_API_KEY` into the LiteLLM environment and loaded dynamically in [configmap.yaml](file:///home/nick/src/fog/apps/base/litellm/configmap.yaml) (`os.environ/VLLM_API_KEY`).

---

## 3. Codifying Virtual Keys (GitOps Integration)

Instead of manual key creation, a Kubernetes bootstrap Job (`apps/base/litellm/bootstrap-job.yaml`) runs on startup to guarantee the following keys exist:

1.  **Gas Town Workers (`gastown-workers`)**: Scoped to the `utility-tier` and `worker-tier`.
2.  **Hermes/Mayor (`hermes-mayor`)**: Scoped to the `executive-tier`, `worker-tier`, and `utility-tier`.

The job runs a curl bootstrap script mounted from `bootstrap-configmap.yaml`, pulling the `LITELLM_MASTER_KEY` securely from the cluster secrets.

