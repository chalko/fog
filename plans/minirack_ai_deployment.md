# 10" Mini-Rack local AI Cluster Deployment Plan

This deployment plan outlines the steps required to provision, install, and configure the local 10-inch mini-rack AI cluster using the **TerraMaster F8-SSD Plus** as the central high-speed storage backend, the **Asus Ascent GX10** as the primary GPU worker, and a **Minisforum server** for utility/routing (LiteLLM, local classifiers, DNS, and secrets).

---

## 1. Hardware Checklist & Procurement

### Core Rack Components
* [ ] **10" Wall-Mount Cabinet / Open Frame**: Minimum 9U height and **at least 350 mm depth** to accommodate cable bend radii.
* [ ] **10" PDU**: 1U rackmount power strip with surge protection (minimum 10A / 1200W rating).
* [ ] **10" Patch Panel & Keystones**: 1U 8-to-12 port panel for clean cable entry.
* [ ] **Cooling**: 1U dual exhaust fan tray (or rear-mounted quiet high-static-pressure fans).

### Servers & Storage
* [ ] **GPU Host**: Asus Ascent GX10 (1.6L chassis, NVIDIA GB10 Grace Blackwell Superchip, 128GB Unified Memory).
* [ ] **Utility Host**: Minisforum MS-01 (equipped with dual 10G SFP+ ports).
* [ ] **10Gb NAS**: TerraMaster F8-SSD Plus.
  * [ ] 8x M.2 2280 NVMe SSDs (e.g. 2TB/4TB models depending on storage requirements).
* [ ] **Network Switch**: MikroTik CRS305-1G-4S+IN (10Gb SFP+).
  * [ ] 3D-printed 10" rackmount ears for CRS305.
  * [ ] 3x SFP+ DAC (Direct Attach Copper) cables (1m length).

---

## 2. Physical Layout & Assembly (Stacking Order)

Mount components in the following vertical order inside a 12U cabinet to optimize thermal dissipation, cable management, and user interaction:

```
[12U] 10" Patch Panel & Keystones
[11U] MikroTik CRS305 (10Gb Switch)
[9U-10U] Voice-AI & Monitoring Hub (LCD Screen, Speakers, Microphone)
[8U]  10" PDU (facing rear)
[7U]  Minisforum MS-01 (Utility Host)
[6U]  Thermal Buffer (1U Blank Panel)
[4U-5U] Asus Ascent GX10 (GPU Host) -- Requires 1U clearance above/below
[1U-3U] TerraMaster F8-SSD Plus (Laid flat on a 3U shelf)
[0U]  Cooling Fan Tray (Bottom Intake)
```

---

## 3. Step-by-Step Implementation Flow

### Phase 1: Storage Provisioning (TerraMaster F8-SSD Plus)
1. **Initialize Drives**: Insert the 8x M.2 NVMe SSDs into the F8-SSD Plus slots.
2. **Flash Operating System**:
   * Option A: Use default **TOS 6** and configure standard storage pools.
   * Option B: Flash **TrueNAS Scale** via USB boot for native ZFS pool support.
3. **Configure Storage Array**:
   * Create a high-throughput storage pool (ZFS RAIDZ1 or RAID 10 equivalent) using the M.2 drives.
   * Set up a dedicated dataset for model weights (e.g., `/mnt/pool0/models`).
4. **Enable NFS Service**:
   * Export the `/mnt/pool0/models` directory over NFS.
   * Restrict access to the subnets occupied by the Minisforum server and the Asus GX10.

### Phase 2: High-Speed Networking Setup
1. Mount the **MikroTik CRS305** using the 3D-printed rackmount ears.
2. Interconnect devices with SFP+ DAC cables:
   * **Port 1**: Asus GX10 (ConnectX-7 SFP+).
   * **Port 2**: Minisforum MS-01 (10G SFP+ Port 1).
   * **Port 3**: TerraMaster F8-SSD Plus 10GbE Port (using an SFP+ to RJ45 10G transceiver).
   * **Port 4**: Uplink to main house router.
3. Configure MTU size to **9000 (Jumbo Frames)** across all SFP+ interfaces to maximize NFS read/write performance.

### Phase 3: GPU Host (Asus Ascent GX10) Configuration
1. Mount the NFS share from the F8-SSD Plus to the GX10's `/workspace/` mountpoint:
   ```bash
   sudo mount -t nfs <nas-ip>:/mnt/pool0/models /workspace/models
   ```
2. Configure vLLM to utilize `/workspace/models` as its Hugging Face cache directory.
3. Verify local loading speed of a 20GB+ model (e.g. `Qwen2.5-Coder-32B-Instruct`). Targeted load time is **<20 seconds** over the 10Gb link.

### Phase 4: Routing & Orchestration (LiteLLM)
1. Update `configmap.yaml` in the Kubernetes LiteLLM namespace to route the `worker-tier` to the Asus GX10 endpoint:
   ```yaml
   - model_name: worker-tier
     litellm_params:
       model: openai/qwen2.5-coder:32b
       api_base: http://<asus-gx10-ip>:8000/v1
   ```
2. Deploy changes and verify failover behaviors (e.g. falling back to the local Minisforum `utility-tier` if the GX10 is offline or powered down to save electricity).
