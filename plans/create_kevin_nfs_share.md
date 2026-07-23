# Plan: Create NFS Share "kevin" on misty

This plan outlines the steps to create a new ZFS dataset named `kevin` from the `local-fast-zfs` pool on the Proxmox VE host (`misty`, `10.7.82.10`), configure it as an NFS share, and export it.

As per your requirements, there is **no need to isolate or protect the data**, so we will authorize access to both the **fog** (`10.7.82.0/24`) and **lodge** (`10.5.110.0/24`) networks, mapping connections to a standard user for clean file permissions. We also limit the share size to **0.5T (500G)**.

---

## 1. Parameters & Environment

*   **Proxmox Host (NFS Server):** `misty` (`misty.fog.chalko.com` / `10.7.82.10`)
*   **Target ZFS Storage Pool:** `local-fast-zfs`
*   **Target Dataset:** `local-fast-zfs/kevin`
*   **ZFS Dataset Quota:** `500G` (0.5T)
*   **NFS Export Path:** `/local-fast-zfs/kevin`
*   **Allowed Network Subnets:** 
    *   **fog network:** `10.7.82.0/24`
    *   **lodge network:** `10.5.110.0/24`
*   **Ownership User/Group:** `nick:nick` (UID `1000`, GID `1000` - matching existing user permissions to ensure trouble-free access)

---

## 2. Execution Steps (Proxmox Host)

Run these commands as `root` on the Proxmox host `misty`:

### Step 1: Create ZFS Dataset & Apply Quota
Create the `kevin` dataset under the `local-fast-zfs` storage pool and limit its maximum storage size to `500G`:
```bash
zfs create local-fast-zfs/kevin
zfs set quota=500G local-fast-zfs/kevin
```

### Step 2: Configure ZFS NFS Share
Set the ZFS `sharenfs` property to share the dataset read-write with both the `fog` and `lodge` subnets. We map all incoming requests to UID/GID `1000` to prevent root permission conflicts on client mounts. The `insecure` flag is included to allow macOS clients (like Finder) to connect from non-privileged ports:
```bash
zfs set sharenfs="rw=@10.7.82.0/24:@10.5.110.0/24,all_squash,anonuid=1000,anongid=1000,async,insecure" local-fast-zfs/kevin
```

### Step 3: Set Directory Permissions
Change ownership of the mount directory to UID/GID `1000` and allow full read/write/execute permissions for user and group:
```bash
chown -R 1000:1000 /local-fast-zfs/kevin
chmod 777 /local-fast-zfs/kevin
```

### Step 4: Verify and Reload Export Table
Apply the exports and verify that `/local-fast-zfs/kevin` is correctly listed:
```bash
# Reload exports
exportfs -ra

# Show active exports (resolving IP or hostname)
showmount -e misty.fog.chalko.com
```

---

## 3. Client Mounting Instructions

To access this NFS share from client machines:

### A. Linux Client
*   **Temporary Mount:**
    ```bash
    mkdir -p /mnt/kevin
    sudo mount -t nfs -o rw,soft,intr misty.fog.chalko.com:/local-fast-zfs/kevin /mnt/kevin
    ```
*   **Persistent Mount (`/etc/fstab`):**
    ```text
    misty.fog.chalko.com:/local-fast-zfs/kevin  /mnt/kevin  nfs  rw,soft,intr,rsize=8192,wsize=8192,timeo=14,noauto,x-systemd.automount  0  0
    ```

### B. iMac (macOS) Client
For macOS clients, NFS mounts require the `resvport` option if the server requires connections from secure ports, but we also specify standard tuning options (`locallocks` handles lock performance on macOS).

*   **Option 1: GUI (Finder - Easiest)**
    1. Open Finder.
    2. Press `Cmd + K` (or go to **Go** -> **Connect to Server...**).
    3. Enter the server address:
       ```text
       nfs://misty.fog.chalko.com/local-fast-zfs/kevin
       ```
    4. Click **Connect**. The volume will mount automatically under `/Volumes/kevin`.

*   **Option 2: Terminal Mount**
    ```bash
    # Create the mount point in your home directory
    mkdir -p ~/kevin
    
    # Mount the volume
    sudo mount -t nfs -o rw,soft,intr,resvport,locallocks misty.fog.chalko.com:/local-fast-zfs/kevin ~/kevin
    ```
