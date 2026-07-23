# Tiered LiteLLM Deployment & Integration Plan

This plan details the implementation steps to roll out a cost-optimized, tiered routing infrastructure in the homelab. By placing LiteLLM as the central switchboard, we isolate expensive frontier APIs from high-concurrency coding worker swarms (Gas Town Polecats) and route low-impact background tasks to local CPU-only resources.

---

## 1. Routing & Tier Design

We will configure LiteLLM with three distinct tiers:

| Tier | Logical Model Name | Physical Target Backend | Assigned Models / Roles | Cost Profile |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (Utility)** | `utility-tier` | Proxmox LXC (`ollama.fog.chalko.com`) | `llama3.2:1b`, `nomic-embed-text` (embeddings, routing, formatting) | $0.00 / mo |
| **Tier 2 (Worker)** | `worker-tier` | Rented GPU (RunPod/Vast.ai via Tailscale) | `qwen2.5-coder:32b` or `llama3-70b` (Gas Town Polecats, code generation) | ~$0.40 - $0.70 / hr |
| **Tier 3 (Executive)**| `executive-tier`| Frontier APIs (Gemini 3.5 Pro / Grok) | High-level orchestration (Gas Town Mayor, Hermes main agent) | Pay-per-token API |

---

## 2. Step-by-Step Implementation Flow

### Phase 1: Local ConfigMap & Secret Integration (K8s) - [COMPLETED]
1.  **Modify Configuration**: Updated [configmap.yaml](file:///home/nick/src/fog/apps/base/litellm/configmap.yaml) to define model lists (`utility-tier`, `worker-tier`, `executive-tier`) and fallback router parameters.
2.  **Define Environment Variables**: Secrets synced from Vault using ExternalSecrets for Gemini and xAI API keys.
3.  **Deploy Changes**: Commited configurations and reconciled with Flux.

### Phase 2: Rented GPU (RunPod) Provisioning - [IN PROGRESS]
1.  **Tailscale Operator in Cluster**: Installed the Tailscale Kubernetes Operator in namespace `tailscale` with OAuth credentials synced from Vault (under path `secret/infrastructure/tailscale`).
2.  **Startup Script Hook**: RunPod container templates will:
    *   Start Tailscale using a pre-authorized ephemeral auth key: `TAILSCALE_AUTHKEY`.
    *   Mount a persistent network volume to `/workspace/` to cache model weights (e.g. `Qwen/Qwen2.5-Coder-32B-Instruct`).
    *   Launch vLLM with cold-start optimization flags:
        ```bash
        vllm serve /workspace/models/Qwen2.5-Coder-32B-Instruct \
          --port 8000 \
          --max-thread-workers 16 \
          --gpu-memory-utilization 0.85
        ```

### Phase 3: Enforce Key-Level Guardrails (LiteLLM Virtual Keys) - [COMPLETED & GITOPS'ED]
1.  **GitOps Seeding Job**: Created the `litellm-bootstrap` Kubernetes Job (`apps/base/litellm/bootstrap-job.yaml`) to automatically verify and register keys in the Postgres DB on startup.
2.  **Worker Key (`gastown-workers`)**:
    *   **Scope**: Access allowed only for `utility-tier` and `worker-tier`.
    *   **Usage**: Configured inside Gas Town's worker rig configs. Cached in `/dev/shm/fog/litellm-virtual-keys.env`.
3.  **Executive Key (`hermes-mayor`)**:
    *   **Scope**: Access allowed for `executive-tier`, `worker-tier`, and `utility-tier`.
    *   **Usage**: Configured inside Hermes configurations and the Gas Town Mayor config. Cached in `/dev/shm/fog/litellm-virtual-keys.env`.

### Phase 4: Application Integration - [PENDING]
1.  **Configure Gas Town rigs**:
    *   Set worker rigs to point to the LiteLLM base URL using the **Worker Key** and the `worker-tier` model alias.
    *   Set the Mayor configuration to use the **Executive Key** and the `executive-tier` model alias.
2.  **Configure Hermes**:
    *   Point `~/.hermes/config.yaml` to the LiteLLM proxy with the **Executive Key** and the `executive-tier` model alias.

---

## 3. Fallback & Safe Mode Behavior - [VERIFIED]

*   **Offline GPU Failover (Tested)**: Verified that when `worker-tier` (pointing to `gpu-node-1`) is offline, LiteLLM automatically times out and falls back to `gemini-flash` then `utility-tier` (local Ollama).
*   **Offline Local Ollama Failover (Tested)**: Verified that if `utility-tier` (local CPU node) fails, it falls back to the low-cost cloud model `gemini-flash-lite`.
*   **API Cost Thresholds**: Set monthly limits directly in the LiteLLM dashboard on the **Executive Key** to guarantee hard caps on total external API spending.
