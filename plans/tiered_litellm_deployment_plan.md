# Tiered LiteLLM Deployment & Integration Plan

This plan details the implementation steps to roll out a cost-optimized, tiered routing infrastructure in the homelab (`fog`). By placing LiteLLM as the central switchboard, we isolate expensive frontier APIs from high-concurrency coding worker swarms (Gas Town Polecats) and route low-impact background tasks to local CPU-only resources.

---

## 1. Routing & Tier Design

We configure LiteLLM with capability-defined 5-tier routing alongside deprecated legacy aliases for backward compatibility:

| Tier | Logical Model Name | Physical Target Backend | Assigned Models & Roles | Cost Profile |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (Executive)** | `executive-tier` | Frontier Cloud APIs (Gemini / Claude / Grok) | Version-agnostic logical aliases (`gemini-pro`, `gemini-flash`, `grok-4.5`). Mayor, Deacon, Crew Lead Agents (Kaylee). | Pay-per-token API |
| **Tier 2A (Worker - General)** | `worker-general` | RunPod GPU (`vLLM` via Tailscale) | `Qwen/Qwen2.5-32B-Instruct` (AWQ/FP8). General worker tasks, document synthesis, workflow execution. | $2.00 / hr (RunPod Pod) |
| **Tier 2B (Worker - Coder)** | `worker-coder` | RunPod GPU (`vLLM` via Tailscale) | `Qwen/Qwen2.5-Coder-32B-Instruct` (AWQ/FP8). Gas Town Polecats for parallel code generation, unit testing, refactoring. | $2.00 / hr (RunPod Pod) |
| **Tier 3 (Fast Utility)** | `utility-fast` | `misty` CPU Ollama (`ollama.fog.chalko.com`) | `llama3.2:3b` / `qwen2.5:3b`. Dedicated LXC container (VMID 9100, 12 GB RAM, 4 vCPUs). Fast prompt routing & task classification. | $0.00 / mo (local CPU) |
| **Tier 4 (Simple Utility)** | `utility-simple` | `misty` CPU Ollama (`ollama.fog.chalko.com`) | `llama3.2:1b` (JSON formatting & schema validation) and `nomic-embed-text` (vector embeddings). 12 GB LXC RAM. | $0.00 / mo (local CPU) |
| *Legacy Deprecated* | `worker-tier` / `utility-tier` | RunPod GPU / `misty` Ollama | Backward compatibility aliases for Gas City workers during migration. | Same as targets |

---

## 2. Step-by-Step Implementation Flow

### Phase 1: Local ConfigMap & Secret Integration (K8s) - [COMPLETED]
1.  **Modify Configuration**: Updated [`apps/base/litellm/configmap.yaml`](file:///home/nick/src/fog/apps/base/litellm/configmap.yaml) to define model lists (`executive-tier`, `worker-general`, `worker-coder`, `utility-fast`, `utility-simple`, plus legacy aliases) and fallback router parameters.
2.  **Define Environment Variables**: Secrets synced from Vault using ExternalSecrets for Gemini, xAI, and vLLM API keys.
3.  **Deploy Changes**: Committed configurations and reconciled with Flux.

### Phase 2: Rented GPU (RunPod) Provisioning - [COMPLETED]
1. **Active Pod Deployment**: Deployed container pod `qwen-vllm-v063` (`ms68rc2gadvzu5`) running `vllm/vllm-openai:v0.6.3` with `Qwen/Qwen2.5-Coder-32B-Instruct-AWQ` ($2.00/hr). Documented in [`docs/hardware/runpod.md`](file:///home/nick/src/fog/docs/hardware/runpod.md).
2. **ConfigMap Update**: Updated LiteLLM `worker-coder` / `worker-general` targets in [`apps/base/litellm/configmap.yaml`](file:///home/nick/src/fog/apps/base/litellm/configmap.yaml) to point to `https://ms68rc2gadvzu5-8000.proxy.runpod.net/v1`.

### Phase 3: Enforce Key-Level Guardrails (LiteLLM Virtual Keys) - [COMPLETED & VERIFIED]
1.  **GitOps Seeding Job**: Configured script in [`apps/base/litellm/bootstrap-configmap.yaml`](file:///home/nick/src/fog/apps/base/litellm/bootstrap-configmap.yaml) mounted into `litellm-bootstrap` Kubernetes Job (`apps/base/litellm/bootstrap-job.yaml`) to automatically verify and register keys on startup.
2.  **Gas Town Workers Key (`gastown-workers`)**:
    *   **Scope**: Access allowed for `worker-coder`, `worker-general`, `utility-fast`, `utility-simple` (plus legacy `worker-tier`, `utility-tier`).
    *   **Usage**: Sourced from `/dev/shm/fog/litellm-secret.env` and used by Gas Town worker rigs for inference.
3.  **Gas Town Crew Key (`gastown-crew`)**:
    *   **Scope**: Access allowed for `executive-tier`, `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`.
    *   **Usage**: Configured inside Gas Town Mayor agent & interactive crew sessions.
4.  **Hermes Agent Key (`hermes`)**:
    *   **Scope**: Access allowed for `executive-tier`, `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`.
    *   **Usage**: Configured inside standalone Hermes main agent.
5.  **Legacy Key (`hermes-mayor`)**:
    *   **Scope**: Maintained as a deprecated key for backwards compatibility until Gas City migration completes.

### Phase 4: Application Integration - [IN PROGRESS]
1. **Configure Gas Town Rigs & Agents**:
    * **Mayor Configuration**: Uses `executive-tier` via LiteLLM (`gastown-crew` key).
    * **Worker Polecats Configuration**: Routes worker traffic via `gastown-workers` key pointing to LiteLLM `worker-coder` / `worker-general` / `utility-fast`.

---

## 3. Fallback & Safe Mode Behavior - [VERIFIED]

*   **Offline GPU Failover (Tested)**: Verified that when `worker-coder` / `worker-general` is offline, LiteLLM automatically times out (120s limit) and falls back to `gemini-flash` then `utility-fast` (`llama3.2:3b` on `misty` CPU).
*   **Offline Local Ollama Failover (Tested)**: Verified that if `utility-fast` / `utility-simple` (local CPU node) fails in WAN mode, it falls back to low-cost cloud model `gemini-flash-lite`.
*   **API Cost Thresholds**: Monthly spending caps configured in the LiteLLM proxy dashboard on executive keys to guarantee hard limits on external API spending.
