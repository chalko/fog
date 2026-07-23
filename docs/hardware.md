# Hardware Inventory

This document tracks the hardware specifications of nodes and machines in
the home lab.

## Cluster / Host Nodes

### Node 1: Minisforum UM760 Slim

- **Form Factor**: Mini PC
- **CPU**: AMD Ryzen 5 7640HS (6 Cores / 12 Threads)
- **RAM**: 32 GB DDR5 (~29.4 GB usable at Proxmox level; ~2.6 GB reserved for
  integrated GPU and Proxmox host kernel)
- **Storage**: 512 GB PCIe Gen4 SSD (boot/root) + 2 TB Samsung 970 EVO Plus
  NVMe SSD (`local-fast-zfs` pool)
- **Primary Role**: Proxmox VE Host (`misty`), hosting Kubernetes
  controlplane/worker nodes and HashiCorp Vault.

## Proxmox Resource Allocation Matrix

| VMID   | VM/LXC Name     | Type       | Cores | RAM   | Rationale                             |
| :----- | :-------------- | :--------- | :---- | :---- | :------------------------------------ |
| **9010**| `k8s-control-01`| VM (Talos) | 2     | 4 GB  | Control plane (etcd, k8s API).        |
| **9020**| `k8s-worker-01` | VM (Talos) | 4     | 8 GB  | App host (Gitea, Postgres, etc.).     |
| **9090**| `vault`         | LXC        | 1     | 1 GB  | External Vault. Low usage (~50 MB).   |
| **9100**| `ollama`        | LXC        | 4     | 12 GB | Dedicated standalone Ollama host.     |
| -      | *ZFS ARC*       | Cache      | -     | 4 GB  | Memory-capped pool for read cache.    |
| -      | *Host Overhead* | OS Buffer  | -     | 0.4 GB| Leftover pool for Proxmox services.   |

*Total Physical RAM Split*: 32 GB total = 2.6 GB Proxmox Host GPU/Kernel reservation + 29.4 GB allocated (25 GB VM/LXC + 4.4 GB ZFS/Host services).

