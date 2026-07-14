# Adding Samsung 970 EVO Plus NVMe Storage to misty

This plan outlines the steps for installing and configuring a secondary Samsung 970 EVO Plus M.2 NVMe SSD on the Proxmox VE host `misty` (Minisforum UM760 Slim).

We will initialize the new drive using **LVM-Thin** to optimize memory availability on this 16GB RAM system.

---

## Phase 1: Pre-Installation & Backups
1. **VM & Container Backups**: Run a manual backup of any critical VMs/LXCs in the Proxmox Web GUI (**Datacenter** -> **Backup**) or via CLI.
2. **Stop Workloads**: Gracefully stop all running VMs and containers.
3. **Graceful Shutdown**: Shut down the Proxmox host `misty`:
   ```bash
   ssh root@10.7.82.10 "poweroff"
   ```

---

## Phase 2: Physical Installation
1. **Power & Disconnect**: Unplug the power adapter and all cables from the UM760 Slim.
2. **Discharge Static**: Press and hold the power button for 15 seconds to drain any residual charge.
3. **Open Chassis**: Remove the rubber feet pads on the bottom, unscrew the cover, and lift the lid.
4. **Insert SSD**:
   - Insert the Samsung 970 EVO Plus into the empty secondary M.2 2280 PCIe slot at a 30-degree angle.
   - Press down flat and secure it with the M.2 mounting screw.
5. **Reassemble**: Close the lid, reinstall the screws/pads, reconnect all cables, and power on.

---

## Phase 3: Post-Installation Verification
1. **OS Detection**: Once booted, SSH into misty and run `lsblk` to verify the drive is detected (typically as `/dev/nvme1n1`).
   ```bash
   ssh root@10.7.82.10 "lsblk"
   ```
2. **Check Drive Health**:
   ```bash
   ssh root@10.7.82.10 "smartctl -a /dev/nvme1n1"
   ```

---

## Phase 4: Proxmox Configuration (LVM-Thin)
We will initialize the drive as an LVM-Thin pool to host our high-performance VM/LXC disks.

1. **Wipe Disk**:
   - Navigate to **Datacenter** -> **pve (node)** -> **Disks**.
   - Select `/dev/nvme1n1` and click **Wipe Disk**.
2. **Create LVM-Thin Pool**:
   - Go to **Disks** -> **LVM-Thin** -> click **Create: Thinpool**.
   - **Disk**: Select `/dev/nvme1n1`.
   - **Name**: `local-fast-lvm` (or `samsung-lvm`).
   - Click **Create**.
3. **Configure Storage Roles**:
   - Verify that under **Datacenter** -> **Storage**, the new pool is configured to only allow **Disk Images** and **Containers**.

---

## Phase 5: VM Migration
Migrate heavy-I/O virtual machine disks (such as Kubernetes worker nodes and databases) to the new pool:
1. Select the target VM in the Web GUI (e.g., `k8s-worker-01`).
2. Go to **Hardware** -> select the disk (e.g., `scsi0`).
3. Click **Volume Action** -> **Move Storage**.
4. Set the **Target Storage** to the newly created Samsung LVM-Thin pool.
5. Check **Delete Source** and click **Move** (this can be done live while the VM is running).
