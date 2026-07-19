# Hardware Inventory

This document tracks the hardware specifications of nodes and machines in the home lab.

## Cluster / Host Nodes

### Node 1: Minisforum UM760 Slim

- **Form Factor**: Mini PC
- **CPU**: AMD Ryzen 5 7640HS (6 Cores / 12 Threads)
- **RAM**: 16 GB DDR5 (~13.4 GB usable at host level after hardware/graphics reservation)
- **Storage**: 512 GB PCIe Gen4 SSD (boot/root) + 2 TB Samsung 970 EVO Plus NVMe SSD (`local-fast-zfs` pool)
- **Primary Role**: Proxmox VE Host (`misty`), hosting Kubernetes controlplane/worker nodes and HashiCorp Vault.

## Proxmox Resource Allocation Matrix

| VMID | VM/LXC Name | Type | vCPU Cores | RAM Allocation | Allocation Rationale |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **9010** | `k8s-control-01` | VM (Talos) | 2 Cores | 4 GB | Control plane node. Minimum recommended resources to run `etcd` and Kubernetes API components stably under typical load. |
| **9020** | `k8s-worker-01` | VM (Talos) | 2 Cores | 10 GB | Application host. Allocated the majority of the host RAM to allow apps (Gitea, PostgreSQL, Nginx) and memory-burstable workloads (Ollama) to run on the same node without re-provisioning VMs. |
| **9090** | `vault` | LXC | 1 Core | 1 GB | External HashiCorp Vault. Deployed as a lightweight container. Real runtime memory usage is extremely low (~50 MB), making 1 GB a conservative safety ceiling. |

*Total Host Overcommit*: 15 GB allocated vs. 13.4 GB usable. Safe because average actual RAM consumption is ~10.4 GB, but VM RAM usage must be monitored to avoid host-level swap/OOM.
