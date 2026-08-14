# RunPod GPU Cloud Deployment

This document tracks active cloud GPU workloads deployed on [RunPod](https://console.runpod.io/).

---

## Active Workload Overview

| Property | Details |
| :--- | :--- |
| **Pod Name** | `qwen-vllm-v063` |
| **Pod ID** | [`ms68rc2gadvzu5`](https://console.runpod.io/pods) |
| **Model** | `Qwen/Qwen2.5-Coder-32B-Instruct-AWQ` |
| **Engine** | `vllm/vllm-openai:v0.6.3` *(Pinned stable release)* |
| **Hardware** | 1x NVIDIA GPU Cloud Pod (24GB+ VRAM) |
| **Cost** | `$2.00 / hr` |
| **Status** | **RUNNING & SERVING** |
| **Console Link** | [RunPod Console Pods](https://console.runpod.io/pods) |

---

## API Endpoints

| Service | URL |
| :--- | :--- |
| **Direct vLLM API** | `https://ms68rc2gadvzu5-8000.proxy.runpod.net/v1` |
| **Direct Health Endpoint**| `https://ms68rc2gadvzu5-8000.proxy.runpod.net/health` |
| **LiteLLM Proxy Endpoints**| `https://llm.fog.chalko.com/v1/chat/completions` (Models: `worker-coder`, `worker-general`, `worker-tier`) |

---

## LiteLLM Integration & Secrets

* **LiteLLM Model Tiers:** `worker-coder` (Coder swarms) and `worker-general` (General workers). (`worker-tier` supported for legacy compatibility).
* **Custom Headers Required:** `User-Agent: vLLM/Client` (Bypasses Cloudflare WAF on `proxy.runpod.net`)
* **Health Check Probe:** `GET /health` (Ultra-lightweight, 0-byte payload, zero GPU compute)
* **Virtual Keys:**
  * `gastown-workers`: Gas Town Polecat worker rigs (`worker-coder`, `worker-general`, `utility-fast`, `utility-simple`).
  * `gastown-crew`: Mayor and interactive crew agent sessions (`executive-tier`, `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`).
  * `hermes`: Standalone Hermes main agent (`executive-tier`, `worker-coder`, `worker-general`, `utility-fast`, `utility-simple`).

---

## Container Configuration

* **Image:** `vllm/vllm-openai:v0.6.3`
* **Docker Arguments:** `--model Qwen/Qwen2.5-Coder-32B-Instruct-AWQ --tensor-parallel-size 1 --enforce-eager --enable-auto-tool-choice --tool-call-parser hermes`
* **Ports Exposed:** `8000/http`, `22/tcp`
* **Disk Allocation:** 50 GB Container Disk + 100 GB Workspace Volume

---

## Sample API Verification Query

```bash
curl -X POST https://ms68rc2gadvzu5-8000.proxy.runpod.net/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-Coder-32B-Instruct-AWQ",
    "messages": [{"role": "user", "content": "Write a python function to check if a number is prime."}],
    "max_tokens": 100
  }'
```

---

## Management Instructions

Secrets and credentials are managed via `pass` and cached in memory per workspace rules:

```bash
# Refresh RunPod secrets cache
keeper runpod

# Query active pod status via runpodctl
source /dev/shm/fog/runpod-secret.env
runpodctl pod get ms68rc2gadvzu5
```
