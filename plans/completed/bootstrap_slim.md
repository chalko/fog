# Bootstrapping Plan & Naming Convention

This plan outlines the initialization steps for our Minisforum UM760 Slim host and establishes the naming convention for all nodes in the home lab.

## Naming Convention

Since the repository is named `fog`, we will adopt an **atmospheric and weather phenomena** naming convention.

### Hostname Architecture
- **Proxmox VE Hosts**: Named after clouds or fog types (e.g., `stratus`, `cumulus`, `mist`).
- **VMs / LXCs (Infrastructure)**: Named after weather states (e.g., `breeze`, `gale`, `tempest`).
- **Kubernetes Nodes**: Prefixed by role (e.g., `k8s-control-01`, `k8s-worker-01`).

### Current Node Assignment
- **Minisforum UM760 Slim**: `mist` (Proxmox VE Host)

---

## Bootstrapping Plan for `mist` (Minisforum UM760 Slim)

### Phase 1: BIOS Configuration
1. Power on the UM760 Slim and enter UEFI/BIOS (typically via `Del` or `F2`).
2. **Enable Virtualization support**: Ensure AMD-V (SVM Mode) is enabled.
3. **Power options**: Set to Power On after power failure.
4. **Boot order**: Set USB as primary boot option for installation.

### Phase 2: Proxmox VE OS Installation
1. Flash the Proxmox VE ISO to a USB drive (e.g., using Ventoy or Rufus).
2. Boot `mist` from the USB.
3. Follow the Proxmox installation UI:
   - **Target Harddisk**: Select the 512GB NVMe SSD (ext4 or ZFS single disk format).
   - **Hostname**: `mist.local` (or your chosen internal domain, e.g., `mist.fog.home`).
   - **IP Address**: Assign a static IP (e.g., `10.7.82.10/24` or another free IP in the `10.7.82.0/24` range). Note: The port is an access port for VLAN 613 (fog), so no VLAN tagging is needed on the host interface.
   - **Gateway**: Router interface on the fog VLAN (e.g., `10.7.82.1`).
   - **DNS Server**: Router interface or chosen DNS server.

### Phase 3: Post-Install Setup & Secrets
1. Access the web UI at `https://10.7.82.10:8006` (or the IP configured).
2. Disable the Enterprise Repository and enable the **No-Subscription Repository** to receive updates.
3. Add the initial credentials to your password-store:
   ```bash
   pass insert fog/proxmox/api_url          # E.g., https://192.168.1.100:8006/api2/json
   pass insert fog/proxmox/api_token_id     # Once API token is generated
   pass insert fog/proxmox/api_token_secret # Once API token is generated
   ```
