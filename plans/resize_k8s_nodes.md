# Plan: Resize Kubernetes Nodes (Memory & Disk) on misty

This plan outlines the steps to safely resize the CPU, RAM, and Disk storage allocations for our Kubernetes nodes (`k8s-control-01` and `k8s-worker-01`) on **misty**.

---

## Current vs Proposed Allocation

| VM Name | VMID | Current RAM | Proposed RAM | Current Disk | Proposed Disk |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`k8s-control-01`** | 9010 | 4 GB (4096 MB) | **4 GB** (4096 MB) | 20 GB | **40 GB** |
| **`k8s-worker-01`** | 9020 | 4 GB (4096 MB) | **10 GB** (10240 MB) | 40 GB | **150 GB** |

---

## Phase 1: Modify Terraform Configuration
We will update `cluster/variables.tf` to match the proposed values:

```hcl
  default = {
    "k8s-control-01" = { vmid = 9010, cores = 2, memory = 4096, disk = 40, ip = "10.7.82.15", mac = "BC:24:11:21:FD:75" }
    "k8s-worker-01"  = { vmid = 9020, cores = 2, memory = 10240, disk = 150, ip = "10.7.82.16", mac = "BC:24:11:6F:84:D1" }
  }
```

---

## Phase 2: Graceful Shutdown
To ensure data consistency during the volume resize, we will gracefully shut down the VMs:

1. SSH into misty and run:
   ```bash
   qm shutdown 9010
   qm shutdown 9020
   ```
2. Wait for the status of both VMs to transition to `stopped` in the Proxmox GUI or by running:
   ```bash
   qm list
   ```

---

## Phase 3: Apply the Resize via Terraform
We will run Terraform to modify the disk sizes and memory values on the Proxmox host:

1. Run the plan to verify the changes:
   ```bash
   source /dev/shm/fog/proxmox.env
   terraform plan
   ```
   *Expected output: Updates in-place for memory and disk sizes.*
2. Apply the changes:
   ```bash
   terraform apply
   ```

---

## Phase 4: Startup & Verification
1. Start the VMs:
   ```bash
   qm start 9010
   qm start 9020
   ```
2. **Auto-Resize Verification:** Talos Linux automatically resizes its partition table and expands the filesystem on boot when it detects a physical disk size change.
3. Check the status of the cluster nodes once booted:
   ```bash
   kubectl --kubeconfig kubeconfig get nodes
   ```
