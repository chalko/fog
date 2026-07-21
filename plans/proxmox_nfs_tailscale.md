# Plan: Secure Proxmox ZFS NFS Share with Tailscale SSO

This plan outlines the steps to overlay Tailscale onto the ZFS NFS share configured for the Obsidian Wiki. By routing NFS traffic through a Tailscale Tailnet, we encrypt the NFS traffic in transit and enforce Google SSO (`@chalko.com`) authentication before clients can access the files.

---

## 1. Prerequisites & Parameters

*   **Tailnet Authentication:** Google Workspace SSO (`@chalko.com`)
*   **Proxmox Host:** `misty`
*   **Target ZFS Dataset:** `local-fast-zfs/users/nick/wiki`
*   **Proxmox Tailscale IP:** *To be determined post-install* (e.g., `100.120.10.15`)
*   **Client Laptop Tailscale IP:** *To be determined post-install* (e.g., `100.120.10.20`)

---

## 2. Step 1: Install & Configure Tailscale on Proxmox (Misty)

Run the following commands as `root` on the Proxmox host (`misty`):

1. **Install Tailscale:**
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

2. **Authenticate with Google SSO (@chalko.com):**
   Run the login command. Click the generated URL and authenticate using your `@chalko.com` workspace credentials:
   ```bash
   tailscale up
   ```

3. **Get the Proxmox Tailscale IP:**
   ```bash
   tailscale ip -4
   ```
   *Note down the `100.x.y.z` address.*

---

## 3. Step 2: Configure Client Laptop

1. **Install Tailscale** on your laptop (via official package manager or app store).
2. **Login** using your `@chalko.com` credentials.
3. Verify connectivity by pinging the Proxmox host over the Tailnet:
   ```bash
   ping <Proxmox-Tailscale-IP>
   ```

---

## 4. Step 3: Restrict ZFS NFS Share to Tailnet

Once connectivity is verified over Tailscale, modify the ZFS `sharenfs` settings on Proxmox to lock down the share.

1. **Allow access only via the Tailscale subnet or specific Client IPs:**
   Tailscale IPs reside in the `100.64.0.0/10` range. We can restrict access to just that subnet:
   ```bash
   zfs set sharenfs="rw=@100.64.0.0/10,all_squash,anonuid=1000,anongid=1000,async" local-fast-zfs/users/nick/wiki
   ```
   *(Optional)* For maximum security, restrict the share exclusively to your laptop's specific Tailscale IP:
   ```bash
   zfs set sharenfs="rw=@<Laptop-Tailscale-IP>,all_squash,anonuid=1000,anongid=1000,async" local-fast-zfs/users/nick/wiki
   ```

2. **Reload NFS exports:**
   ```bash
   exportfs -ra
   ```

---

## 5. Step 4: Update Client Mount Configurations

Update your client mounts to use the secure Tailscale IP.

*   **Manual Mount (Temporary):**
   ```bash
   sudo umount ~/Documents/wiki
   sudo mount -t nfs -o rw,soft,intr <Proxmox-Tailscale-IP>:/local-fast-zfs/users/nick/wiki ~/Documents/wiki
   ```

*   **Persistent Mount (`/etc/fstab`):**
    Replace the local LAN IP (`10.7.82.10`) with the Proxmox Tailscale IP:
    ```text
    <Proxmox-Tailscale-IP>:/local-fast-zfs/users/nick/wiki  /home/nick/Documents/wiki  nfs  rw,soft,intr,rsize=8192,wsize=8192,timeo=14,noauto,x-systemd.automount  0  0
    ```
