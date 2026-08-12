# Multi-Tiered Backup & Disaster Recovery Architecture for Dolt

## Overview
This document outlines the multi-tiered backup strategy and disaster recovery plan for the **Dolt SQL Server** (`dolt.fog.chalko.com`) running in the `fog` Kubernetes cluster.

---

## 1. Multi-Phase Architecture

### **Phase 1: Local High-Frequency Snapshots (Near-Zero RPO)**
* **Technology**: ZFS dataset snapshots on Proxmox hypervisor (`misty`) / Kubernetes VolumeSnapshots.
* **Frequency**: Every 1 hour.
* **Retention**: 48 hours rolling retention.
* **Purpose**: Immediate recovery from accidental data corruption or botched batch transactions.

### **Phase 2: Off-Site Cloud Storage Replication (Daily & Weekly)**
* **Technology**: Dolt native remote push (`dolt backup sync` / `dolt push`) & `rclone` to Google Cloud Storage (`gs://fog-dolt-backups-chalko`).
* **Credentials**: Managed via HashiCorp Vault (`secret/data/app/gcs-backups`) and synced into Kubernetes via External Secrets Operator (`ESO`).
* **Schedule**:
  * **Daily Incremental**: Executed every night at 02:00 UTC. Retained for 30 days.
  * **Weekly Archive**: Executed every Sunday at 03:00 UTC into Coldline storage class. Retained for 1 year.
* **Purpose**: Protection against host hardware loss, datacenter failure, or total site disaster.

### **Phase 3: Automated Disaster Recovery & Restore Validation**
* **Local Restore**: Instant ZFS dataset rollback or PVC restore from snapshot.
* **Off-Site Restore**: Step-by-step runbook for cloning `gs://fog-dolt-backups-chalko` back into fresh Dolt PVC.

---

## 2. Secrets & Security Control

* No static GCS credentials in Git.
* Service account key stored in Vault (`secret/data/app/gcs-backups`).
* Access controlled by Kubernetes RBAC and network policies.

---

## 3. Red-Team & Failure-Mode Analysis Requirements
*(To be evaluated by Red-Team Polecat review)*

1. **Active Write Locking**: How does Dolt handle snapshots/backups during concurrent write transactions?
2. **Vault Outage Dependency**: Can Dolt recover if Vault is temporarily sealed or unreachable?
3. **Storage Quota & Decay**: What happens if the GCS bucket or local ZFS pool hits quota limits?
