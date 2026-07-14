# Vault Installation & Kubernetes Bootstrapping Plan

This document outlines the step-by-step procedure for installing and configuring HashiCorp Vault on the Proxmox LXC container (`vault`, IP: `10.7.82.90`), initializing/unsealing it, and configuring integration with the Kubernetes cluster.

---

## Phase 1: Install Vault on Proxmox LXC (Debian 12)

Since the container `vault` (VMID `9090`) is already created and running, we will SSH into it to install HashiCorp Vault.

### 1. Repository Setup & Installation
Connect to the container via SSH or the Proxmox console and run:

```bash
# SSH into the Vault container
ssh root@10.7.82.90

# Install prerequisites
apt-get update && apt-get install -y gpg coreutils curl

# Add HashiCorp GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp official Debian repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Install Vault
apt-get update && apt-get install -y vault
```

### 2. Configure Vault
Edit `/etc/vault.d/vault.hcl`. For a single-node home lab instance, we will configure standard file-system storage (or Raft) and disable TLS for simplicity (or configure self-signed certs).

```hcl
# /etc/vault.d/vault.hcl
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

storage "file" {
  path = "/opt/vault/data"
}

ui = true
disable_mlock = true
```

Ensure the storage directory exists and has the correct permissions:
```bash
mkdir -p /opt/vault/data
chown -R vault:vault /opt/vault/data /etc/vault.d
```

### 3. Start Vault Service
Start and enable the systemd unit:
```bash
systemctl daemon-reload
systemctl enable --now vault
systemctl status vault
```

---

## Phase 2: Initialize & Unseal Vault

Once the service is active, initialize and retrieve the master/unseal keys.

### 1. Initialization
Run the initialization command:
```bash
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator init -key-shares=5 -key-threshold=3 > /root/vault-init.txt
```

> [!IMPORTANT]
> Immediately extract the **Unseal Keys** and **Initial Root Token** from `/root/vault-init.txt` and save them securely in your local secret store (`pass`). Delete `/root/vault-init.txt` afterwards:
> ```bash
> pass insert fog/vault/root_token
> # Add keys to pass: fog/vault/unseal_key_1, etc.
> rm /root/vault-init.txt
> ```

### 2. Unseal the Vault
Unseal the storage engine using 3 of the 5 keys:
```bash
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>
```

Verify status:
```bash
vault status
```

---

## Phase 3: Integrate with Kubernetes Cluster

We will configure Vault's Kubernetes authentication backend so that pods running inside our cluster (`k8s-control-01` / `k8s-worker-01`) can authenticate using service accounts.

### 1. Enable K8s Auth Backend
Log in using the root token and enable the engine:
```bash
export VAULT_TOKEN="<root-token>"
vault auth enable kubernetes
```

### 2. Configure K8s Client Info
To allow Vault to verify service account tokens against the Kubernetes API, configure the auth engine:

```bash
# Inside Vault LXC container, configure with local cluster variables
vault write auth/kubernetes/config \
    kubernetes_host="https://10.7.82.90:6443" \
    disable_iss_validation="true"
```
*(Note: Replace the `kubernetes_host` with the actual control plane endpoint if it is different).*

### 3. Create a Access Policy
Create a file `k8s-read-policy.hcl` allowing read access to secrets:
```hcl
path "secret/data/app/*" {
  capabilities = ["read"]
}
```
Write it to Vault:
```bash
vault policy write k8s-read k8s-read-policy.hcl
```

### 4. Bind Policy to K8s Service Account
Create a role matching a Kubernetes namespace and ServiceAccount name:
```bash
vault write auth/kubernetes/role/app-role \
    bound_service_account_names=app-sa \
    bound_service_account_namespaces=default \
    policies=k8s-read \
    ttl=24h
```

---

## Phase 4: Deploy Kubernetes Support (External Secrets Operator)

Rather than running Vault sidecars, using the **External Secrets Operator (ESO)** is the modern best practice for syncing Vault secrets into native Kubernetes Secrets.

### 1. Install ESO via Helm
On your local machine (with `kubeconfig` loaded):
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace
```

### 2. Configure ClusterSecretStore
Create `k8s/vault-store.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://10.7.82.90:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "app-role"
          serviceAccountRef:
            name: "app-sa"
            namespace: "default"
```
Apply it to the cluster:
```bash
kubectl apply -f k8s/vault-store.yaml
```
