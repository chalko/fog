# Project Plan: Install Gitea on Kubernetes

This document details the plan to deploy Gitea on the home lab Kubernetes cluster. It adheres to the repository's rules regarding IaC, secrets management via HashiCorp Vault, and External Secrets Operator (ESO).

---

## 1. Architectural Design

We will deploy Gitea using the official Helm chart inside a dedicated namespace (`gitea`).

### Components:
1. **Gitea Core Application**: Run as a Deployment/StatefulSet (managed by the Helm chart).
2. **Database (PostgreSQL)**: We will leverage the PostgreSQL sub-chart bundled with the Gitea Helm chart for simplified storage and lifecycle management.
3. **Secrets Management**: Plaintext secrets (e.g., database passwords, admin passwords) will reside in HashiCorp Vault (`http://10.7.82.90:8200`) and sync via External Secrets Operator (ESO) using a namespace-scoped `ExternalSecret`.
4. **Ingress & DNS**: Expose the service using an Ingress rule pointing to the local cluster's ingress controller, integrating with external-dns if configured.

---

## 2. Secrets Management (Vault & ESO Setup)

To avoid hardcoded credentials, we will configure a role in HashiCorp Vault that authorizes the `gitea` ServiceAccount to read Gitea secrets.

### Step 2.1: Update Terraform Vault Configuration
We need to update [vault_config.tf](file:///home/nick/src/fog/cluster/vault_config.tf) to include the `gitea` namespace in the allowed Kubernetes Service Account namespaces:

```diff
 resource "vault_kubernetes_auth_backend_role" "app_role" {
   backend                          = vault_auth_backend.kubernetes.path
   role_name                        = "app-role"
   bound_service_account_names      = ["app-sa"]
-  bound_service_account_namespaces = ["default", "external-dns"]
+  bound_service_account_namespaces = ["default", "external-dns", "gitea"]
   token_policies                   = [vault_policy.k8s_read.name]
   token_ttl                        = 86400
 }
```

### Step 2.2: Populate Vault Secrets
Add the sensitive configuration options to Vault under `secret/data/app/gitea`:
- `db_password`: Database password for PostgreSQL.
- `admin_password`: Initial administrator password for Gitea.
- `secret_key`: Gitea internal security token (optional/auto-generated, but best to pin if necessary).

Run these commands on the host machine or via the Vault UI:
```bash
vault kv put secret/app/gitea \
    db_password="<secure-db-password>" \
    admin_password="<secure-admin-password>"
```

### Step 2.3: Create Kubernetes Namespace and Service Account
Create a manifest to initialize the namespace, ServiceAccount, and `ExternalSecret`.

`k8s/gitea-secrets.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gitea
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: gitea
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gitea-secrets
  namespace: gitea
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: gitea-secrets
    creationPolicy: Owner
  data:
    - secretKey: db-password
      remoteRef:
        key: secret/data/app/gitea
        property: db_password
    - secretKey: admin-password
      remoteRef:
        key: secret/data/app/gitea
        property: admin_password
```

---

## 3. Helm Values Configuration

We will customize the Gitea Helm Chart configuration in `k8s/gitea-values.yaml`.

`k8s/gitea-values.yaml`:
```yaml
# Configuration values for Gitea on Kubernetes
gitea:
  admin:
    username: "admin"
    passwordKey: "admin-password"
    existingSecret: "gitea-secrets"
  
  config:
    APP_NAME: "Chalko Home Lab Git Service"
    security:
      INSTALL_LOCK: true # Prevent the web installer from appearing

# PostgreSQL database sub-chart settings
postgresql:
  enabled: true
  auth:
    database: "gitea"
    username: "gitea"
    existingSecret: "gitea-secrets"
    secretKeys:
      adminPasswordKey: "db-password"
      userPasswordKey: "db-password"
  primary:
    persistence:
      enabled: true
      size: "8Gi"
      storageClass: "local-path" # Adjust this to matches the cluster's storage provisioner

# Storage for Gitea repositories
persistence:
  enabled: true
  size: "16Gi"
  storageClass: "local-path"

# Ingress Controller Configuration
ingress:
  enabled: true
  className: "nginx" # Adjust depending on your cluster ingress controller (e.g. nginx, traefik)
  hosts:
    - host: gitea.fog.chalko.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - gitea.fog.chalko.com
      secretName: gitea-tls

# Custom health probes referencing Gitea's healthz endpoint
giteaProbes:
  liveness:
    httpGet:
      path: /api/healthz
      port: http
    initialDelaySeconds: 200
    timeoutSeconds: 5
    periodSeconds: 10
    successThreshold: 1
    failureThreshold: 10
  readiness:
    httpGet:
      path: /api/healthz
      port: http
    initialDelaySeconds: 200
    timeoutSeconds: 5
    periodSeconds: 10
    successThreshold: 1
    failureThreshold: 3
```

---

## 4. Execution Roadmap

1. **Apply Terraform changes** to allow the `gitea` ServiceAccount to authenticate with Vault.
2. **Populate secrets** inside Vault under `secret/data/app/gitea`.
3. **Deploy Vault synchronization and namespace resources**:
   ```bash
   kubectl apply -f k8s/gitea-secrets.yaml
   ```
4. **Add and update Helm repository**:
   ```bash
   helm repo add gitea-charts https://dl.gitea.com/charts/
   helm repo update
   ```
5. **Install Gitea Chart**:
   ```bash
   helm install gitea gitea-charts/gitea -f k8s/gitea-values.yaml -n gitea
   ```
