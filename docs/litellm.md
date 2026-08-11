# LiteLLM Tier Routing & Virtual Keys

This document details the configuration, tier architecture, fallback routing, and virtual key management for **LiteLLM** running on the `fog` cluster.

---

## 1. Overview & Architectural Pointers

LiteLLM operates as the central switchboard for the `fog` homelab and Gas Town agent swarms, insulating external API budgets from heavy batch workloads and routing CPU-friendly tasks to local hardware.

Key configuration manifests in this repository:
* **LiteLLM Router ConfigMap**: [`apps/base/litellm/configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/configmap.yaml) — Defines `model_list`, model aliases, and fallback chains.
* **External Secrets Integration**: [`apps/base/litellm/secrets.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/secrets.yaml) — Mounts Gemini, xAI, and `vLLM` API keys synced from Vault.
* **Bootstrap Key Seeding**: [`apps/base/litellm/bootstrap-job.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/bootstrap-job.yaml) and [`apps/base/litellm/bootstrap-configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/bootstrap-configmap.yaml) — Automatic registration of virtual keys on startup.
* **Local Hardware Context**: [`docs/hardware.md`](file:///home/nick/gt-city/rigs/fog/docs/hardware.md) — Host specifications (`misty` PVE host & `ollama` LXC container VMID 9100).

---

## 2. Model Tier Structure & Hardware Backends

| Numeric Tier | Tier Name | Logical Alias in LiteLLM | Physical Backend Target | Assigned Models & Specifications | Cost Profile |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | **Executive** | `executive-tier` | Frontier Cloud APIs (Gemini / Claude / Grok) | Mapped via version-agnostic logical aliases (`gemini-pro`, `gemini-flash`, `grok-4.5`). High reasoning depth for Mayor & Crew Lead Agents. | Pay-per-token API |
| **Tier 2A** | **Worker - General** | `worker-general` | RunPod GPU (`vLLM` over Tailscale) | `Qwen/Qwen2.5-32B-Instruct` (AWQ/FP8). Non-coding worker tasks, document synthesis, workflow execution. | $2.00 / hr (RunPod Pod) |
| **Tier 2B** | **Worker - Coder** | `worker-coder` | RunPod GPU (`vLLM` over Tailscale) | `Qwen/Qwen2.5-Coder-32B-Instruct` (AWQ/FP8). Gas Town Polecat swarms for parallel coding, unit testing, refactoring. | $2.00 / hr (RunPod Pod) |
| **Tier 3** | **Fast Utility** | `utility-fast` | `misty` CPU Ollama (`ollama.fog.chalko.com`) | `llama3.2:3b` / `qwen2.5:3b`. Dedicated LXC container (VMID 9100, 12 GB RAM, 4 vCPUs). Fast prompt routing & task classification. | $0.00 / mo (local CPU) |
| **Tier 4** | **Simple Utility** | `utility-simple` | `misty` CPU Ollama (`ollama.fog.chalko.com`) | `llama3.2:1b` (JSON structure & schema validation) and `nomic-embed-text` (vector embeddings). 12 GB LXC RAM allocation. | $0.00 / mo (local CPU) |

---

## 3. Version Governance & Model Aliases

To allow upgrading underlying AI models independently without altering application configs or tier names:
1. **Gemini Pro**: Mapped to `gemini-pro` alias $\rightarrow$ `gemini/gemini-3.1-pro-preview` in [`apps/base/litellm/configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/configmap.yaml).
2. **Gemini Flash**: Mapped to `gemini-flash` alias $\rightarrow$ `gemini/gemini-3.6-flash` in [`apps/base/litellm/configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/configmap.yaml).
3. **Gemini Flash Lite**: Mapped to `gemini-flash-lite` alias $\rightarrow$ `gemini/gemini-3.5-flash-lite` in [`apps/base/litellm/configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/configmap.yaml).

When Google or xAI releases new versions, update the physical model mapping string under `model_list` in [`apps/base/litellm/configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/configmap.yaml) and reconcile via Flux.

---

## 4. Fallback Routing & Safe Mode

Configured in [`apps/base/litellm/configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/configmap.yaml) under `router_settings.fallbacks`:

* **Worker GPU Failover**: If the RunPod GPU endpoint (`worker-coder` / `worker-general`) is offline or timing out (120s limit):
  * **WAN Mode**: Automatically falls back to `gemini-flash` $\rightarrow$ `utility-fast` (`llama3.2:3b`).
  * **Air-Gapped / Offline Mode**: Bypasses external WAN endpoints and falls back directly to local `utility-fast` (`llama3.2:3b` on `misty` LXC).
* **Local Ollama Failover**: If `utility-fast` / `utility-simple` fails in WAN mode, traffic falls back to low-cost `gemini-flash-lite`.

---

## 5. Virtual Keys & Access Scoping

Virtual keys are automatically seeded into Postgres on startup via [`apps/base/litellm/bootstrap-configmap.yaml`](file:///home/nick/gt-city/rigs/fog/apps/base/litellm/bootstrap-configmap.yaml):

1. **Gas Town Workers (`gastown-workers`)**:
   * **Allowed Tiers**: `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`.
   * **Usage**: Injected into Gas Town Polecat worker rig environment configs.
2. **Gas Town Crew & Mayor (`gastown-crew`)**:
   * **Allowed Tiers**: `executive-tier`, `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`.
   * **Usage**: Injected into Gas Town Mayor agent & interactive crew agent sessions.
3. **Hermes Agent (`hermes`)**:
   * **Allowed Tiers**: `executive-tier`, `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`.
   * **Usage**: Injected into Hermes main agent system configuration.
