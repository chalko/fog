# Service Catalog & Topology

This document provides a comprehensive overview of all infrastructure, platform controllers, and user-facing services running across the `fog` homelab environment.

---

## 1. Top-Level Network & DNS Routing

* **Ingress Controller IP**: `10.7.82.16` (ingress-nginx)
* **Internal DNS Server**: Pi-hole (`10.5.110.3`)
* **Subdomain Separation**:
  * `*.fog.chalko.com`: Managed by Kubernetes `external-dns` & `ingress-nginx`.
  * `*.node.fog.chalko.com`: Managed by `proxmox-dns-sync` & static Terraform records in Pi-hole.

---

## 2. Infrastructure & Hypervisor Layer (Proxmox VE & Direct VMs)

Managed via Terraform in [`provision/`](file:///home/nick/gt-city/rigs/fog/provision/):

| Service / Host | Role / Purpose | Endpoint / IP | Management |
| :--- | :--- | :--- | :--- |
| **`misty`** | Proxmox VE 8.x Hypervisor Host | `10.7.82.10`<br>`https://misty.node.fog.chalko.com:8006` | Proxmox VE |
| **`gx10-2b2a`** (ASUS Ascent GX10) | Dedicated AI Micro-Server / Workstation | `gx10-2b2a.lodge.chalko.com` | Standalone Node |
| **HashiCorp Vault** | Central Secrets Management & Encryption Engine | `https://10.7.82.90:8200`<br>`vault.node.fog.chalko.com` | Terraform / Pass |
| **Ollama GPU Host** | Dedicated VM with GPU Passthrough for Local LLMs | `http://10.7.82.100:11434`<br>`ollama.node.fog.chalko.com` | Proxmox VM / Terraform |
| **Talos K8s Nodes** | Immutable OS Kubernetes Control Plane & Worker Nodes | `10.7.82.50+` range | Talos Linux / Terraform |
| **NFS Share** | Central Network Storage for persistent mounts | `10.7.82.10` / `truenas` | Proxmox / ZFS |

---

## 3. Kubernetes Platform & Operators (`infrastructure/base/`)

Platform controllers deployed and reconciled via FluxCD GitOps:

| Operator / Service | Namespace | Purpose | Endpoint / Ingress |
| :--- | :--- | :--- | :--- |
| **`ingress-nginx`** | `ingress-nginx` | Cluster Ingress Controller & Layer 7 HTTP Routing | `10.7.82.16` |
| **`cert-manager`** | `cert-manager` | Automated ACME TLS Certificates (Let's Encrypt Production) | ClusterIssuers: `letsencrypt-prod`, `letsencrypt-staging` |
| **`external-secrets`** | `vault-integration` | Synchronizes runtime secrets from HashiCorp Vault into K8s Secrets | Internal operator |
| **`proxmox-dns-sync`** | `external-dns` | CronJob syncing Proxmox VM IPs to Pi-hole DNS | `*/5 * * * *` CronJob |
| **`tailscale-operator`** | `tailscale` | Exposes internal cluster services securely via Tailnet mesh | Tailnet Device Gateway |
| **`grafana`** | `monitoring` | Observability dashboards (K8s, Proxmox, LiteLLM, Ollama) | `https://grafana.fog.chalko.com` |
| **`coredns-fog`** | `kube-system` | In-cluster DNS resolution and upstream forwarding | `10.96.0.10` |

---

## 4. Application Workloads (`apps/base/`)

User-facing services and developer tooling deployed via FluxCD:

| Application | Namespace | Description | Ingress / Endpoint | Storage / Persistence |
| :--- | :--- | :--- | :--- | :--- |
| **Gitea** | `gitea` | Self-hosted Git service & FluxCD GitOps origin | `https://gitea.fog.chalko.com`<br>SSH: `port 30222` | PostgreSQL (8Gi) + Data (16Gi) |
| **Capacitor** | `capacitor` | Web UI & control panel for FluxCD GitOps | `https://capacitor.fog.chalko.com` | Stateless |
| **LiteLLM** | `litellm` | AI Gateway, virtual key management & provider proxy | `https://llm.fog.chalko.com`<br>`https://litellm.fog.chalko.com` | PostgreSQL / Redis |
| **Open-WebUI** | `open-webui` | Full-featured conversational AI chat interface | `https://chat.fog.chalko.com` | 10Gi (`local-path`) |
| **Ollama (Cluster)** | `ollama` | Internal cluster Ollama gateway & inference worker | `https://ollama.fog.chalko.com` | Model storage (`local-path`) |
| **Hermes** | `hermes` | AI Agent gateway and webhook automation platform | `https://hermes.fog.chalko.com` | 5Gi (`local-path`) |
| **Dolt** | `dolt` | Version-controlled SQL database for Beads & memory | `https://dolt.fog.chalko.com`<br>SQL: `port 3307` | 20Gi (`local-path`) |
| **Olah** *(in flight)* | `olah` | Pull-through caching mirror for Hugging Face models | `https://hf.fog.chalko.com` | 100Gi (`local-path`) |
| **Harbor** *(in flight)* | `harbor` | Container registry and pull-through caching proxy | `https://harbor.fog.chalko.com` | Registry Storage (`local-path`) |

---

## 5. Security & Secret Mappings

1. **Vault Engine**: `https://10.7.82.90:8200`
2. **K8s Secret Bridge**: `ExternalSecret` custom resources mapped in each application directory (e.g. `apps/base/<app>/secrets.yaml`).
3. **Ingress Security**: All public-facing ingresses enforce TLS encryption via `cert-manager.io/cluster-issuer: letsencrypt-prod`.
