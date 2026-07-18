# HashiCorp Vault Setup & Kubernetes Integration

This document outlines the architecture, manual management procedures, and integration patterns for the HashiCorp Vault instance running in the home lab.

## Architecture

Vault is deployed outside the Kubernetes cluster to avoid bootstrapping circular dependencies (e.g., if Kubernetes needs Vault secrets to start).

```
┌─────────────────────────────────┐          ┌──────────────────────────┐
│          Proxmox VE             │          │    Kubernetes Cluster    │
│  ┌───────────────────────────┐  │          │  ┌────────────────────┐  │
│  │   LXC Container (9090)    │  │          │  │  External Secrets  │  │
│  │  ┌─────────────────────┐  │  │  HTTPS   │  │   Operator (ESO)   │  │
│  │  │ HashiCorp Vault     │◀─┼──┼──────────┼─▶│                    │  │
│  │  │ (10.7.82.90:8200)   │  │ (TLS IP)  │  │  ClusterSecretStore│  │
│  │  └─────────────────────┘  │  │          │  └────────────────────┘  │
│  └───────────────────────────┘  │          └──────────────────────────┘
└─────────────────────────────────┘
```

- **Platform**: Proxmox LXC Container (Debian 12, unprivileged, nesting enabled)
- **VMID**: `9090`
- **Hostname**: `vault`
- **Static IP**: `10.7.82.90` (Listening on port `8200` over HTTPS)
- **Storage Backend**: Local filesystem (`/opt/vault/data`)

---

## Configuration & TLS

### Memory Locking (`mlock`)
Because Vault runs inside an unprivileged LXC container, memory locking (`mlock`) syscalls are restricted. Vault is configured with memory locking disabled in `/etc/vault.d/vault.hcl`:
```hcl
disable_mlock = true
```

### Self-Signed TLS
Vault generates and uses a self-signed certificate stored in `/opt/vault/tls/`. 
To allow secure client verification from Kubernetes without domain names or hostname resolving, the certificate is generated with the IP SAN explicitly registered:
```bash
subjectAltName = IP:10.7.82.90,DNS:vault,DNS:localhost
```

---

## Secrets Management & Unsealing

The Vault master keys and root tokens are stored securely in your local password-store (`pass`).

### Retrieve Credentials
To retrieve the root token or unseal keys:
```bash
pass show fog/vault/root_token
pass show fog/vault/unseal_key_1
pass show fog/vault/unseal_key_2
pass show fog/vault/unseal_key_3
```

### Unsealing Vault
Whenever the Vault LXC container or the service restarts, Vault starts in a **sealed** state. You can unseal it using one of the following methods:

#### Method A: From your local computer (Recommended)
If you have initialized your secure environment cache using `source bin/load-env.sh`, you can unseal Vault directly from your laptop/desktop without SSHing into Proxmox:
```bash
# 1. Load the Vault environment
source /dev/shm/fog/vault.env

# 2. Fetch the keys from pass into memory
KEY1=$(pass show fog/vault/unseal_key_1)
KEY2=$(pass show fog/vault/unseal_key_2)
KEY3=$(pass show fog/vault/unseal_key_3)

# 3. Unseal Vault
vault operator unseal "$KEY1"
vault operator unseal "$KEY2"
vault operator unseal "$KEY3"
```

#### Method B: From the Proxmox host
1. SSH into the Proxmox host (`10.7.82.10`).
2. Run the unseal command inside the container using 3 of the 5 keys:
```bash
pct exec 9090 -- env VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator unseal <unseal-key-1>
pct exec 9090 -- env VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator unseal <unseal-key-2>
pct exec 9090 -- env VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator unseal <unseal-key-3>
```

---

## Kubernetes Integration

### 1. Token Reviewer RBAC
A service account `vault-reviewer` in the `kube-system` namespace is granted the `system:auth-delegator` role. Vault uses this service account's token to query the Kubernetes API and verify the identity of pods requesting secrets.
Manifests: [vault-auth-setup.yaml](file:///home/nick/src/fog/infrastructure/base/vault-integration/vault-auth-setup.yaml)

### 2. Vault Kubernetes Auth Backend
The Kubernetes authentication method is enabled and managed via **Terraform**.
- **Mount Path**: `kubernetes`
- **K8s API Endpoint**: `https://10.7.82.15:6443`
- **Configurations**: Managed inside [provision/vault_config.tf](file:///home/nick/src/fog/provision/vault_config.tf)

### 3. External Secrets Operator (ESO)
ESO runs inside Kubernetes to automatically fetch secrets from Vault and sync them as native Kubernetes `Secret` resources.
- **Helm Deployment**: Deployed in the `external-secrets` namespace.
- **Trust Configuration**: The Vault self-signed certificate is stored in the K8s secret `vault-tls-ca` inside the `external-secrets` namespace.
- **ClusterSecretStore**: The [vault-store.yaml](file:///home/nick/src/fog/infrastructure/base/vault-integration/vault-store.yaml) manifest configures the connection between ESO and Vault.

---

## Adding Secrets & Roles

### 1. Creating a Policy
Access permissions are defined via Vault policies. For example, `k8s-read` allows reading paths under `secret/data/app/*`:
```hcl
path "secret/data/app/*" {
  capabilities = ["read"]
}
```

### 2. Binding to a Kubernetes ServiceAccount
Create a backend role mapping a K8s namespace and service account:
```hcl
resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "app-role"
  bound_service_account_names      = ["app-sa"]
  bound_service_account_namespaces = ["default"]
  token_policies                   = ["k8s-read"]
}
```
This configuration is managed inside [provision/vault_config.tf](file:///home/nick/src/fog/provision/vault_config.tf).

---

## Backup & Disaster Recovery

Since Vault is deployed in an LXC container using a local filesystem storage backend (`/opt/vault/data`), backups must be scheduled at the host or container level.

### 1. Proxmox VE Backups (Recommended)
The primary backup mechanism is Proxmox VE's built-in backup tool (VZDump/PBS):
- **Target**: LXC Container `9090` (`vault`).
- **Mode**: `Snapshot` (allows zero-downtime hot backups).
- **Schedule**: Automatically configured to back up to PBS or local-backup storage weekly.

### 2. Manual Data Backups
To take a manual snapshot of the encrypted Vault storage files directly:
1. SSH to Proxmox VE host (`10.7.82.10`).
2. Create a tarball of the data directory:
   ```bash
   pct exec 9090 -- tar -czf /tmp/vault-data-backup.tar.gz -C /opt/vault/data .
   ```
3. Copy the archive out of the container:
   ```bash
   pct pull 9090 /tmp/vault-data-backup.tar.gz ./vault-data-backup.tar.gz
   ```

> [!CAUTION]
> The raw data backup is encrypted at rest using Vault's key ring. To restore and read this data, you **MUST** have the original unseal keys. Always ensure your unseal keys are securely backed up in `pass` before a recovery event.

