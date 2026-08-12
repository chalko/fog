# DNS Architecture & Subdomain Policy

This document outlines the DNS record structure, resolution policies, and automated sync controllers operating in the `fog` homelab environment.

---

## 1. Subdomain Namespace Separation

To prevent DNS record flapping and ownership collisions between hypervisor-level VMs and Kubernetes ingress controllers, hostnames are strictly divided into two logical namespaces:

| Subdomain Scope | Purpose | Managed By | Example Hostnames | Target IP Pattern |
| :--- | :--- | :--- | :--- | :--- |
| **`*.fog.chalko.com`** | Kubernetes Ingresses & Cluster Services | `external-dns` (K8s) | `dolt.fog.chalko.com`<br>`gitea.fog.chalko.com`<br>`ollama.fog.chalko.com`<br>`llm.fog.chalko.com` | `10.7.82.16` (Ingress Controller) |
| **`*.node.fog.chalko.com`** | Proxmox Hypervisors & Direct VM IPs | `proxmox-dns-sync` & Terraform ([`provision/dns.tf`](file:///home/nick/gt-city/rigs/fog/provision/dns.tf)) | `misty.node.fog.chalko.com`<br>`ollama.node.fog.chalko.com`<br>`vault.node.fog.chalko.com` | `10.7.82.10` (Proxmox host)<br>`10.7.82.100` (Direct VM IP) |

---

## 2. Sync Controller Roles

### **ExternalDNS (`external-dns`)**
* **Namespace**: `external-dns`
* **Target Domain Filter**: `fog.chalko.com`
* **Function**: Monitors K8s `Ingress` resources and automatically manages corresponding `A` records in Pi-hole (`10.5.110.3`).

### **Proxmox DNS Sync (`proxmox-dns-sync`)**
* **Namespace**: `external-dns` (CronJob scheduled `*/5 * * * *`)
* **Target Domain Suffix**: `node.fog.chalko.com`
* **Function**: Queries Proxmox VE API (`misty`) for active VM/LXC network interfaces and updates `*.node.fog.chalko.com` entries in Pi-hole.

---

## 3. Static Terraform DNS Rules (`provision/dns.tf`)

Static local DNS overrides are declared in [`provision/dns.tf`](file:///home/nick/gt-city/rigs/fog/provision/dns.tf) to ensure critical infrastructure records persist even during controller restarts:

```hcl
resource "pihole_local_dns" "misty_node" {
  hostname = "misty.node.fog.chalko.com"
  ip       = "10.7.82.10"
}

resource "pihole_local_dns" "ollama_node" {
  hostname = "ollama.node.fog.chalko.com"
  ip       = "10.7.82.100"
}

resource "pihole_local_dns" "dolt" {
  hostname = "dolt.fog.chalko.com"
  ip       = "10.7.82.16"
}
```
