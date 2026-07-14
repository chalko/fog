# Plan: ZFS Storage Migration and VM Resource Resizing on misty

This plan outlines the steps to convert the secondary 2TB Samsung NVMe drive entirely into a **unified ZFS pool** (`local-fast-zfs`), configure ZFS memory constraints on the Proxmox host, and resize the resource allocations (RAM and Disk) for your Kubernetes nodes and Vault.

---

## Proposed Resource Allocation

| VM Name | VMID | Current RAM | Proposed RAM | Current Disk | Proposed Disk | Target Storage Pool |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`k8s-control-01`** | 9010 | 4 GB (4096 MB) | **4 GB** (4096 MB) | 20 GB | **40 GB** | `local-fast-zfs` |
| **`k8s-worker-01`** | 9020 | 4 GB (4096 MB) | **10 GB** (10240 MB) | 40 GB | **150 GB** | `local-fast-zfs` |
| **`vault` (LXC)** | 9090 | 512 MB (default) | **1 GB** (1024 MB) | 8 GB | **16 GB** | `local-fast-zfs` |

---

## Phase 1: Evacuate Samsung SSD (Moving Data to Boot Drive)
To re-initialize the Samsung drive without losing data, we will temporarily move all VM/LXC disks to the boot drive (`local-lvm` which has >340GB free space).

1. **Vault (LXC 9090):** Shut down the container and move its disk:
   ```bash
   ssh root@10.7.82.10 "pct stop 9090 && pct move_volume 9090 rootfs local-lvm --delete 1"
   ```
2. **Kubernetes controlplane & worker (VMs 9010 & 9020):** Move their disks live (without shutdown):
   ```bash
   ssh root@10.7.82.10 "qm move_disk 9010 scsi0 local-lvm --delete && qm move_disk 9010 efidisk0 local-lvm --delete"
   ssh root@10.7.82.10 "qm move_disk 9020 scsi0 local-lvm --delete && qm move_disk 9020 efidisk0 local-lvm --delete"
   ```

---

## Phase 2: Destroy LVM & Create Unified ZFS Pool
Once the Samsung SSD (`/dev/nvme1n1`) is empty, we will reformat it entirely as a ZFS pool.

1. **Remove Proxmox storage configuration:**
   * Go to **Datacenter** $\rightarrow$ **Storage** $\rightarrow$ select `local-fast-lvm` $\rightarrow$ click **Remove**.
2. **Destroy LVM structures on Samsung SSD:**
   ```bash
   ssh root@10.7.82.10 "lvremove -y local-fast-lvm && vgremove local-fast-lvm && pvremove /dev/nvme1n1"
   ```
3. **Wipe physical partitions:**
   ```bash
   ssh root@10.7.82.10 "wipefs -a /dev/nvme1n1"
   ```
4. **Create ZFS Pool:**
   Create a single-disk ZFS pool named **`local-fast-zfs`** in Proxmox:
   * Go to **pve (node)** $\rightarrow$ **Disks** $\rightarrow$ **ZFS** $\rightarrow$ click **Create: ZFS**.
   * Name: `local-fast-zfs`
   * Disk: Select `/dev/nvme1n1`
   * RAID Level: `Single Disk`
   * Click **Create**.

---

## Phase 3: Limit ZFS RAM Usage (ARC Cache)
Since **misty** has 16GB of RAM, we must prevent ZFS from consuming too much memory by capping the ARC cache size to **2 GB**.

1. SSH into misty and create/edit the ZFS options file:
   ```bash
   ssh root@10.7.82.10 "echo 'options zfs zfs_arc_max=2147483648' > /etc/modprobe.d/zfs.conf"
   ```
2. Update the initramfs to apply the change on next boot:
   ```bash
   ssh root@10.7.82.10 "update-initramfs -u -k all"
   ```

---

## Phase 4: Modify Terraform Configurations & Apply Resizing
We will update the configurations to use `local-fast-zfs` as the datastore ID and apply the disk/RAM updates.

1. **Variables File (`cluster/variables.tf`):** Update VM definitions to the new disk/RAM sizes.
2. **VM Main File (`cluster/main.tf`):** Change `datastore_id` to `"local-fast-zfs"`.
3. **Vault File (`cluster/vault.tf`):** Change `datastore_id` to `"local-fast-zfs"`, set memory dedicated to `1024`, and set disk size to `16`.
4. **Shutdown Kubernetes VMs:**
   ```bash
   ssh root@10.7.82.10 "qm shutdown 9010 && qm shutdown 9020"
   ```
5. **Apply Terraform changes:**
   ```bash
   source /dev/shm/fog/proxmox.env
   terraform apply
   ```
   *Terraform will relocate VM disk storage back to the new `local-fast-zfs` pool and apply the resized disk and RAM values.*

---

## Phase 5: Verification & Boot
1. Start the VMs:
   ```bash
   qm start 9010
   qm start 9020
   pct start 9090
   ```
2. Verify that Talos Linux automatically resizes partitions and filesystems inside the VMs.
3. Unseal Vault using `vault operator unseal`.
4. Check the status of your Kubernetes nodes:
   ```bash
   kubectl --kubeconfig kubeconfig get nodes
   ```
