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

### Phase 1: Local ConfigMap & Secret Integration (K8s)
1.  **Modify Configuration**: Update `apps/base/litellm/configmap.yaml` to define the model list aliases and fallback routers.
2.  **Define Environment Variables**: Ensure Vault has keys populated for:
    *   `gemini_api_key`
    *   `xai_api_key`
3.  **Deploy Changes**: Commit the modified `configmap.yaml` and reconcile Flux.

### Phase 2: Rented GPU (RunPod) Provisioning
1.  **Startup Script Hook**: Configure the RunPod container template to:
    *   Start Tailscale using a pre-authorized ephemeral auth key: `TAILSCALE_AUTHKEY`.
    *   Mount a persistent network volume to `/workspace/` to cache model weights (e.g. `Qwen/Qwen2.5-Coder-32B-Instruct`).
    *   Launch vLLM with cold-start optimization flags:
        ```bash
        vllm serve /workspace/models/Qwen2.5-Coder-32B-Instruct \
          --port 8000 \
          --max-thread-workers 16 \
          --gpu-memory-utilization 0.85
        ```

### Phase 3: Enforce Key-Level Guardrails (LiteLLM Virtual Keys)
Using LiteLLM's dashboard or admin API, generate two keys:
1.  **Worker Key (`sk-worker-xxx`)**:
    *   **Scope**: Access allowed only for `utility-tier` and `worker-tier`.
    *   **Usage**: Configured inside Gas Town's worker rig configs.
2.  **Executive Key (`sk-exec-xxx`)**:
    *   **Scope**: Access allowed for `executive-tier`, `worker-tier`, and `utility-tier`.
    *   **Usage**: Configured inside Hermes configurations and the Gas Town Mayor config.

### Phase 4: Application Integration
1.  **Configure Gas Town rigs**:
    *   Set worker rigs to point to the LiteLLM base URL using the **Worker Key** and the `worker-tier` model alias.
    *   Set the Mayor configuration to use the **Executive Key** and the `executive-tier` model alias.
2.  **Configure Hermes**:
    *   Point `~/.hermes/config.yaml` to the LiteLLM proxy with the **Executive Key** and the `executive-tier` model alias.

---

## 3. Fallback & Safe Mode Behavior

*   **Offline GPU Failover**: If the rented GPU is powered off, LiteLLM's fallback router will intercept the request on `worker-tier` and temporarily downgrade the request to `utility-tier` (local LXC) or redirect it to `executive-tier` (API) to avoid application downtime.
*   **API Cost Thresholds**: Set monthly limits directly in the LiteLLM dashboard on the **Executive Key** to guarantee hard caps on total external API spending.
