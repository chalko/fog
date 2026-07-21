# Plan: Configure Proxmox NFS Share for Obsidian Wiki

This plan outlines the steps to create, configure, and export a high-performance NFS share on the Proxmox VE host (`misty`, `10.7.82.10`) for hosting the user's Obsidian wiki. This shared storage allows both the user's local laptop and the Kubernetes-based Hermes Agent to read and write to the exact same wiki files in real-time.

---

## 1. Environment & Parameters

*   **Proxmox Host (NFS Server):** `misty` (`10.7.82.10`)
*   **Target ZFS Storage Pool:** `local-fast-zfs`
*   **NFS Export Path:** `/local-fast-zfs/users/nick/wiki`
*   **Allowed Network Subnet:** `10.7.82.0/24` (or your specific local network subnet)
*   **Ownership User/Group:** `nick:nick` (UID `1000`, GID `1000`)
*   **Local Mount Path (on Laptop):** `~/Documents/wiki` (or user's preferred local folder)

---

## 2. Proxmox Host Configuration Steps (To be handled by Laptop Agent or Administrator)

Run the following commands as `root` on the Proxmox host (`misty` / `10.7.82.10`):

### Phase A: Dataset Creation
1. **Create the nested ZFS datasets for the user directory and wiki:**
   ```bash
   zfs create local-fast-zfs/users
   zfs create local-fast-zfs/users/nick
   zfs create local-fast-zfs/users/nick/wiki
   ```

### Phase B: NFS Sharing & Security
1. **Set the ZFS NFS sharing properties:**
   Expose the dataset read-write specifically to the designated local client IPs or subnet, mapping all connecting users to standard user UID/GID 1000 to maintain clean permission ownership:
   ```bash
   # Expose to specific client IPs (e.g., laptop 10.7.82.50 and K8s nodes 10.7.82.15 / 10.7.82.16)
   zfs set sharenfs="rw=@10.7.82.15:10.7.82.16:10.7.82.50,all_squash,anonuid=1000,anongid=1000,async" local-fast-zfs/users/nick/wiki
   ```

2. **Verify the NFS export:**
   Ensure the dataset is correctly exported on the network:
   ```bash
   showmount -e 10.7.82.10
   ```
   *Expected output should list `/local-fast-zfs/users/nick/wiki` as accessible.*

### Phase C: Ownership and Permissions
1. **Assign permissions to UID/GID 1000 (standard user `nick`):**
   Restrict directory access strictly to the owner and group:
   ```bash
   chown -R 1000:1000 /local-fast-zfs/users/nick/wiki
   chmod 770 /local-fast-zfs/users/nick/wiki
   ```

2. **Seed Initial Content (Optional):**
   If you want to migrate existing wiki content immediately, populate `/local-fast-zfs/users/nick/wiki/` with your current notes.

---

## 3. Client Configuration Steps

### A. Laptop Mounting (macOS / Linux)
Mount the shared NFS volume on your laptop so Obsidian can open it as a local vault:

*   **Linux / macOS Terminal:**
    ```bash
    mkdir -p ~/Documents/wiki
    sudo mount -t nfs -o rw,soft,intr 10.7.82.10:/local-fast-zfs/users/nick/wiki ~/Documents/wiki
    ```
*   **Persistent Mount (Linux `/etc/fstab`):**
    ```text
    10.7.82.10:/local-fast-zfs/users/nick/wiki  /home/nick/Documents/wiki  nfs  rw,soft,intr,rsize=8192,wsize=8192,timeo=14,noauto,x-systemd.automount  0  0
    ```

### B. Kubernetes Mounting (Hermes Pod)
The Kubernetes deployment for Hermes Agent has already been patched in Gitea under `/apps/base/hermes/helmrelease.yaml` with the following Volume and VolumeMount definitions:

```yaml
    extraVolumes:
      - name: run-dir
        emptyDir: {}
      - name: wiki-volume
        nfs:
          server: 10.7.82.10
          path: /local-fast-zfs/users/nick/wiki
    extraVolumeMounts:
      - name: run-dir
        mountPath: /run
      - name: wiki-volume
        mountPath: /opt/data/wiki
```

Once the Proxmox share is active, commit and push the GitOps updates to Gitea. Flux CD will roll out the updated pod automatically, mounting your real-time Proxmox share under `/opt/data/wiki`.

---

## 4. Verification

1. Create a test file on your laptop:
   ```bash
   echo "Hello from laptop" > ~/Documents/wiki/test.md
   ```
2. Log into the Hermes Agent terminal and verify it can see the file:
   ```bash
   cat /opt/data/wiki/test.md
   ```
3. Verify Hermes can write back to the share:
   ```bash
   echo "Hello from Hermes" >> /opt/data/wiki/test.md
   ```
