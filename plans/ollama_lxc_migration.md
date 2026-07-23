# Plan: Migrate Ollama to Standalone Proxmox LXC Container

This plan outlines the steps to migrate Ollama out of the Kubernetes cluster (`k8s-worker-01` VM) and into a dedicated, standalone Debian-based LXC container on the Proxmox VE host (`misty`).

---

## 1. CPU & Memory Distribution Matrix

By moving Ollama out of Kubernetes, we can reclaim substantial RAM from the `k8s-worker-01` node and re-allocate it to the new `ollama` LXC container.

### Memory Allocations (32 GB Physical Budget)

*   **Total Physical RAM**: 32 GB DDR5
*   **PVE GPU/Kernel Reservation**: 2.6 GB (Hardware reserve for integrated Radeon 760M + Linux kernel)
*   **Total Usable RAM**: 29.4 GB (30,105 MB)

| Component | VMID | Current RAM | Proposed RAM | Change | CPU Cores | Rationale |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`k8s-control-01`** | 9010 | 4 GB | **4 GB** | *No change* | 2 | Talos controlplane (etcd, API server). |
| **`k8s-worker-01`** | 9020 | 20 GB | **8 GB** | **-12 GB** | 4 | Reclaimed memory; 8 GB is plenty for Gitea, PostgreSQL, and other GitOps services. |
| **`vault` (LXC)** | 9090 | 1 GB | **1 GB** | *No change* | 1 | Vault secrets engine. |
| **`ollama` (LXC)** | **9100** | *New* | **12 GB** | **+12 GB** | 4 | Standalone host for model execution. Fits 8B and 14B models comfortably. |
| **ZFS ARC Limit** | - | 4 GB | **4 GB** | *No change* | - | Memory-capped read cache for the `local-fast-zfs` pool. |
| **Host Overhead** | - | 0.4 GB | **0.4 GB** | *No change* | - | Proxmox VE system services buffer. |
| **Total Usable** | - | **29.4 GB** | **29.4 GB** | **0 GB** | **11 (Shared)** | Safe, fully-utilized distribution. |

### CPU Core Strategy
*   **Total Cores/Threads**: 6 Cores / 12 Threads (Ryzen 5 7640HS)
*   Proxmox allows safe CPU overprovisioning. We assign **4 cores** to the `ollama` container to maximize token generation speeds (which are memory-bandwidth bound beyond 4-6 threads on standard DDR5 RAM).

---

## 2. Implementation Steps

### Phase 1: Modify Terraform Configuration
We will configure the new LXC container and update the k8s worker node memory limits.

1.  **Update `provision/variables.tf`**:
    *   Reduce `k8s-worker-01` memory to `8192`.
2.  **Create `provision/ollama.tf`**:
    *   Define a `proxmox_virtual_environment_container` resource for `ollama` (VMID `9100`).
    *   Configure it with:
        *   Cores: `4`
        *   Memory: `12288` (12 GB)
        *   Disk: `40` (to hold downloaded model weights)
        *   OS Template: Debian 12 standard
        *   Network: Static IP `10.7.82.100/24`

### Phase 2: Run Terraform/OpenTofu Apply
Apply the resources changes.
1.  Gracefully stop the worker node to apply the memory resize if not supported live:
    ```bash
    ssh root@10.7.82.10 "qm shutdown 9020"
    ```
2.  Run the apply command:
    ```bash
    terraform apply
    ```
3.  Start the worker node:
    ```bash
    ssh root@10.7.82.10 "qm start 9020"
    ```

### Phase 3: Setup Ollama in the LXC Container
1.  SSH into the new `ollama` LXC container (`10.7.82.100`):
    ```bash
    ssh root@10.7.82.100
    ```
2.  Install Ollama:
    ```bash
    curl -fsSL https://ollama.com/install.sh | sh
    ```
3.  Configure Ollama to bind to `0.0.0.0` so Kubernetes pods and local hosts can reach it:
    *   Edit `/etc/systemd/system/ollama.service` and add:
        ```ini
        [Service]
        Environment="OLLAMA_HOST=0.0.0.0"
        ```
    *   Reload systemd and restart Ollama:
        ```bash
        systemctl daemon-reload
        systemctl restart ollama
        ```

### Phase 4: Configure K8s Services to Use External Ollama
Instead of running Ollama inside the cluster, configure a Kubernetes service to point to the external LXC host.
1.  Create a headless Service and Endpoints pointing to `10.7.82.100` in the target namespace (e.g. `default` or `apps`):
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: ollama
    spec:
      ports:
        - port: 11434
    ---
    apiVersion: v1
    kind: Endpoints
    metadata:
      name: ollama
    subsets:
      - addresses:
          - ip: 10.7.82.100
        ports:
          - port: 11434
    ```
2.  Update internal clients (e.g. agents or UI chat clients) to query the service `http://ollama:11434`.
