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
- **Stack Manifest**: [composeflux.yaml](composeflux.yaml)
- **Compose Definition**: [compose.yaml](compose.yaml)
- **Environment Template**: [.env.example](.env.example)
- **Systemd Unit**: [composeflux.service](composeflux.service)
- **Agent Installer**: [install-composeflux.sh](install-composeflux.sh)
- **Vault Sync Script**: [fetch-vault-secrets.sh](fetch-vault-secrets.sh)
- **Webhook Receiver Spec**: [webhook-receiver.yaml](webhook-receiver.yaml)

### Secret Synchronization from Vault
Secrets (such as `HF_TOKEN`) are stored in HashiCorp Vault (`https://10.7.82.90:8200`) under `secret/data/fog/haze/vllm`.
The host authenticates via Vault AppRole credentials stored in:
- `/etc/composeflux/vault-role-id`
- `/etc/composeflux/vault-secret-id`

Before starting or reconciling the stack, `composeflux.service` runs `fetch-vault-secrets.sh` via `ExecStartPre`, generating `/opt/composeflux/stacks/haze/.env` (mode `0600`).

### Installation on Haze
To test installation in dry-run mode:
```bash
DRY_RUN=true ./install-composeflux.sh
```

To perform live installation on haze (requires root):
```bash
sudo ./install-composeflux.sh
```

> [!WARNING]
> **GPU Host Operational Safety**:
> Do not restart or recreate running model containers during inference or compilation cycles. Check logs with `docker logs -f vllm-qwen38` and monitor GPU status via `nvidia-smi`.

