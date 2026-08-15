# Haze (ASUS Ascent GX10) AI Workload Stack

This directory contains the declarative Docker Compose and ComposeFlux configurations for the dedicated AI inference host **`haze`** (`haze.lodge.chalko.com` / `10.7.82.11`).

## Workloads

### `vllm-qwen38`
- **Image**: `nvcr.io/nvidia/vllm:26.07-py3` (ARM64 optimized NVIDIA container)
- **Model**: `Qwen/Qwen3.8-27B-FP8`
- **Context Length**: 16,384 tokens
- **Port**: `8000` (OpenAI-compatible `/v1/chat/completions` & `/v1/models`)
- **Key Flags**:
  - `NVIDIA_DISABLE_REQUIRE=1`: Disables driver constraint checks for ARM64 container runtime.
  - `--gpu-memory-utilization 0.90`: Reserves optimal VRAM allocation for KV cache and attention kernels.
  - `ipc: host`: Shared memory access for low-latency inference.

## GitOps Deployment with ComposeFlux

This stack is managed declaratively by ComposeFlux:
- Manifest: [composeflux.yaml](composeflux.yaml)
- Compose definition: [compose.yaml](compose.yaml)
- Environment template: [.env.example](.env.example)

> [!WARNING]
> **GPU Host Operational Safety**:
> Do not restart or recreate running model containers during inference or compilation cycles. Check logs with `docker logs -f vllm-qwen38` and monitor GPU status via `nvidia-smi`.
