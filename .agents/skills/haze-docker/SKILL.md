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
3. **Read-Only Observability**:
   * Always monitor container progress via read-only inspection:
     ```bash
     ssh nick@10.7.82.11 "docker ps"
     ssh nick@10.7.82.11 "docker logs --tail 30 vllm-qwen38"
     ssh nick@10.7.82.11 "nvidia-smi"
     ```

---

## 2. Standard Deployment Workflow (Edit ➔ Push ➔ Kick Flux)

Whenever you need to update model configurations, environment variables, or compose services on Haze:

### Step 1: Edit Declarative Manifest
Modify [`hosts/haze/compose.yaml`](file:///home/nick/laredo/rigs/fog/hosts/haze/compose.yaml) in the `fog` repository.

### Step 2: Commit & Push to Git
```bash
git add hosts/haze/compose.yaml
git commit -m "feat(haze): update compose stack configuration"
git push gitea main
```

### Step 3: Kick ComposeFlux Sync
Trigger the ComposeFlux GitOps sync on Haze to apply the newly pushed commit:
```bash
# Webhook trigger (Port 9898)
curl -s -X POST http://10.7.82.11:9898/webhook || true

# Or trigger direct ComposeFlux agent sync
ssh nick@10.7.82.11 "sudo /opt/composeflux/bin/composeflux sync || cd /home/nick/stacks/haze && docker compose up -d"
```

### Step 4: Monitor Warmup & Verify
Tail the startup logs until the OpenAI endpoint comes online:
```bash
# Check GPU memory allocation
ssh nick@10.7.82.11 "nvidia-smi"

# Verify API readiness
curl -s http://10.7.82.11:8000/v1/models
curl -s http://10.7.82.11:8000/health
```

---

## 3. Hardware & Architecture Specifications

* **Silicon**: NVIDIA GB10 Grace Blackwell Superchip (aarch64 / ARM64).
* **VRAM**: 128 GB Unified High-Bandwidth Memory.
* **Driver Requirement**: `nvidia-driver-610-open` (Driver 610.43+, CUDA 13.3) required for NGC 26.x container releases.
* **Kernel & Attention Tuning**:
  * `VLLM_USE_DEEP_GEMM=0`: Disables DeepGemm warmup assertions and falls back to CUTLASS FP8 block-scaled kernels on Blackwell text models.
  * Entrypoint command must use `vllm serve <model>` (e.g. `vllm serve Qwen/Qwen3.8-27B-FP8`).
