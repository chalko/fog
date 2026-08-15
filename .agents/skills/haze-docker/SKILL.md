---
name: haze-docker
description: |
  GitOps workflow, lifecycle management, and operational rules for running Docker & ComposeFlux on the Haze AI inference node (ASUS Ascent GX10 / NVIDIA GB10).
  Use whenever modifying, deploying, or troubleshooting containers and LLM inference stacks on Haze.
---

# Haze Docker & ComposeFlux Operational Skill

This skill defines the mandatory GitOps workflow and operational rules for managing containerized AI inference stacks on the **`haze`** workstation (`10.7.82.11`, ASUS Ascent GX10 / NVIDIA GB10 Grace Blackwell Superchip with 128 GB Unified Memory).

---

## 1. Golden Rules (Zero Ad-Hoc Mutations)

1. **Declarative GitOps Single Source of Truth**:
   * All container definitions on Haze live strictly in [`hosts/haze/compose.yaml`](file:///home/nick/laredo/rigs/fog/hosts/haze/compose.yaml) within the `fog` repository.
   * **Never** run ad-hoc container commands (`docker run`, `docker restart`, `docker stop`, `docker rm`) directly on Haze to experiment or debug.
2. **Uninterrupted Warmup Lifecycles (Rule #6)**:
   * LLM inference engines (vLLM, SGLang, Ollama) on Blackwell require multi-minute initialization cycles (loading 28+ GB safetensors weights into VRAM, allocating 76+ GB KV-cache, and compiling CUDA graph attention kernels).
   * Never interrupt or cycle running containers during their initialization and warmup cycles.
3. **HTTP Observability (No SSH Hacking)**:
   * Monitor service readiness and health via HTTP endpoints:
     ```bash
     curl -s http://10.7.82.11:8000/health
     curl -s http://10.7.82.11:8000/v1/models
     ```

---

## 2. Standard Deployment Workflow (Edit ➔ Push ➔ ComposeFlux)

Whenever you need to update model configurations, environment variables, or compose services on Haze:

### Step 1: Edit Declarative Manifest
Modify [`hosts/haze/compose.yaml`](file:///home/nick/laredo/rigs/fog/hosts/haze/compose.yaml) in the `fog` repository.

### Step 2: Commit & Push to Git
```bash
git add hosts/haze/compose.yaml
git commit -m "feat(haze): update compose stack configuration"
git push origin main
```

### Step 3: Trigger ComposeFlux Sync
Trigger the ComposeFlux GitOps sync on Haze to apply the newly pushed commit:
```bash
# Webhook trigger (Port 9898)
curl -s -X POST http://10.7.82.11:9898/webhook/gitea || true
```

### Step 4: Verify via Health Endpoint
```bash
# Verify API readiness
curl -s http://10.7.82.11:8000/health
curl -s http://10.7.82.11:8000/v1/models
```

---

## 3. Hardware & Architecture Specifications

* **Silicon**: NVIDIA GB10 Grace Blackwell Superchip (aarch64 / ARM64).
* **VRAM**: 128 GB Unified High-Bandwidth Memory.
* **Driver Requirement**: `nvidia-driver-610-open` (Driver 610.43+, CUDA 13.3) required for NGC 26.x container releases.
* **Kernel & Attention Tuning**:
  * `VLLM_USE_DEEP_GEMM=0`: Disables DeepGemm warmup assertions and falls back to CUTLASS FP8 block-scaled kernels on Blackwell text models.
  * Entrypoint command must use `vllm serve <model>` (e.g. `vllm serve Qwen/Qwen3.8-27B-FP8`).
