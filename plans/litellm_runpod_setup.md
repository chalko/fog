# Rented GPU (RunPod/Vast.ai) to Local K8s via LiteLLM Setup Plan

This plan captures architectural decisions and setup notes for integrating ephemeral rented GPUs with a local Kubernetes cluster (Talos Linux on a Minisforum UM760 Slim) using **LiteLLM** and **Tailscale**.

---

## 1. Core Architecture

The system uses a **three-tier routing model** managed by a central **LiteLLM proxy** running in the local Kubernetes cluster:

```
                       ┌─────────────────────────┐
                       │   Gas Town / Hermes     │
                       └────────────┬────────────┘
                                    │ (Calls logical alias)
                                    ▼
                       ┌─────────────────────────┐
                       │      LiteLLM Proxy      │
                       │   (Minisforum / K8s)    │
                       └─────┬───────────┬─────┬─┘
                             │           │     │
       ┌─────────────────────┘           │     └─────────────────────┐
       │ (utility-tier)                  │ (worker-tier)             │ (executive-tier)
       ▼                                 ▼                           ▼
┌──────────────┐                 ┌──────────────┐            ┌──────────────┐
│ Local Ollama │                 │ Rented GPU   │            │ Frontier API │
│ (Proxmox LXC)│                 │ (vLLM via    │            │ (Gemini /    │
│ (CPU Only)   │                 │  Tailscale)  │            │  Claude)     │
└──────────────┘                 └──────────────┘            └──────────────┘
```

*   **Tier 1: Local CPU Ollama (Utility Tier)**
    *   **Host**: Dedicated Proxmox LXC (CPU-only, no iGPU passthrough to avoid driver/reset complications).
    *   **Models**: `llama3.2:1b`, `qwen2.5:1.5b`, `nomic-embed-text`.
    *   **Use Cases**: Vector embeddings, fast intent classification, basic guardrails, and JSON cleanup.
*   **Tier 2: Rented GPU (Worker Tier)**
    *   **Hosts**: Ephemeral/on-demand GPUs (e.g., RunPod RTX 4090 @ ~$0.69/hr or Vast.ai).
    *   **Engine**: vLLM (Docker container with CUDA/PagedAttention).
    *   **Network**: Connected via a **Tailscale** overlay network.
    *   **Use Cases**: Gas Town coding swarms (e.g., Polecat workers).
*   **Tier 3: Frontier APIs (Executive Tier)**
    *   **Endpoints**: Gemini API / Claude API.
    *   **Use Cases**: High-level orchestrators (Hermes main agent, Gas Town Mayor).

---

## 2. LiteLLM Configuration & Guardrails

To prevent accidental credit card charges from rogue background agents, routing is enforced at the **API Key** level in LiteLLM rather than trusting the applications.

### Key Mapping
1.  **Worker Key (`sk-worker-123`)**: Assigned to Gas Town Polecats. Locked strictly to `worker-tier` and `utility-tier`.
2.  **Executive Key (`sk-exec-999`)**: Assigned to Hermes and Gas Town Mayor. Has full access to all tiers, including frontier APIs.

### Example `config.yaml`
```yaml
model_list:
  # TIER 1: Local CPU Ollama (Always-on, $0 compute)
  - model_name: utility-tier
    litellm_params:
      model: ollama/llama3.2:1b
      api_base: "http://<ollama-lxc-ip>:11434"

  # TIER 2: Rented GPU (vLLM over Tailscale)
  - model_name: worker-tier
    litellm_params:
      model: openai/qwen2.5-coder-32b
      api_base: "http://gpu-node-1.tailnet.net:8000/v1"
      api_key: "your_vllm_bearer_token"
      timeout: 60

  # TIER 3: Frontier APIs (Executive Reasoning)
  - model_name: executive-tier
    litellm_params:
      model: gemini/gemini-3.5-pro
      api_key: os.environ/GEMINI_API_KEY

router_settings:
  fallbacks:
    - worker-tier: ["utility-tier", "executive-tier"]
  num_retries: 2
  retry_after: 5

general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
```

---

## 3. Rented GPU Integration Setup (RunPod & Tailscale)

### Tailscale Networking
*   Do not expose raw vLLM endpoints to the public internet.
*   For ephemeral RunPod instances, inject the `TAILSCALE_AUTHKEY` environment variable on boot.
*   RunPod startup scripts automatically initialize the tunnel:
    ```bash
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --authkey=tskey-auth-xxxxxx --hostname=gpu-node-1
    ```

### Cost & Cold-Start Optimizations
To minimize compute charges while maintaining fast spin-up times (<60 seconds):
1.  **Persistent Storage**: Store model weights on a separate Network Volume ($0.07/GB/month) rather than destroying and redownloading weights on every boot.
2.  **Parallel Weight Loading**: Run vLLM with parallel reader threads: `--max-thread-workers 16`.
3.  **Compilation Cache**: Set `TORCH_INDUCTOR_CACHE_DIR=/workspace/torch_cache` pointing to persistent storage to skip CUDA graph compilation steps on subsequent boots.
4.  **Tame CUDA Graphs**: Set `--gpu-memory-utilization 0.85` or `--cudagraph-mode PIECEWISE` to reduce compilation time.

### Automated Boot Hook (Concept)
*   **Fallback Trigger**: Configure a LiteLLM pre-request webhook or fallback callback that invokes the RunPod API to spin up the GPU when the local proxy receives a connection error on `worker-tier`.

---

## 4. Local Host Decoupling: Talos K8s vs. Proxmox LXC

*   **LiteLLM**: Runs inside the Talos Linux K8s cluster (configured stateless, lightweight).
*   **Ollama**: Deploy as a dedicated **CPU-only Proxmox LXC** container (Ubuntu/Debian) rather than inside Kubernetes.
    *   **Why**: Bypasses Kubernetes scheduling/cgroups overhead for multi-threaded OpenMP CPU operations (`llama.cpp`), keeps Talos disk/persistent volume configuration clean of heavy GGUF files, and prevents CPU starvation on K8s control plane nodes during heavy batch operations.
