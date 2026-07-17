# Project Plan: Install Cert-Manager & Configure Let's Encrypt

This document outlines the architecture and execution steps to deploy **Cert-Manager** on the home lab Kubernetes cluster and configure it to automatically issue Let's Encrypt TLS certificates.

---

## 1. ACME Challenge Strategy

To request Let's Encrypt certificates, Cert-Manager must prove domain ownership via one of two ACME challenges:

1. **HTTP-01 Challenge**:
   * *How it works*: Let's Encrypt requests a specific file over port 80 at `http://<your-domain>/.well-known/acme-challenge/`.
   * *Requirement*: Port 80 on your router must be forwarded to the Ingress controller.
2. **DNS-01 Challenge (Recommended for Home Labs)**:
   * *How it works*: Cert-Manager adds a temporary TXT record to your public DNS zone (e.g., Cloudflare, Route53) via API.
   * *Requirement*: A public DNS provider API token. No inbound ports need to be exposed to the internet.

*We will assume the **DNS-01** challenge using **Cloudflare** (or your public DNS provider) is preferred to avoid port forwarding. If you prefer HTTP-01, we can adjust the Issuer.*

---

## 2. Directory Layout & Manifests

We will store Cert-Manager configuration manifests under `k8s/`:

```text
k8s/
├── cert-manager-values.yaml    # Helm values for Cert-Manager
├── cert-manager-secrets.yaml   # ExternalSecret for DNS API token
└── cert-manager-issuers.yaml   # ClusterIssuer resources
```

---

## 3. Vault & Secrets Management

For the DNS-01 challenge, Cert-Manager requires an API token to edit DNS records. We will store this token in Vault at `secret/data/app/cert-manager`.

### Step 3.1: Save Token in Vault
```bash
vault kv put secret/app/cert-manager \
    dns_api_token="<your-dns-provider-api-token>"
```

### Step 3.2: Create ExternalSecret (`k8s/cert-manager-secrets.yaml`)
Create an `ExternalSecret` to sync the API token into the `cert-manager` namespace:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cert-manager-dns-token
  namespace: cert-manager
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: cert-manager-dns-token
    creationPolicy: Owner
  data:
    - secretKey: api-token
      remoteRef:
        key: secret/data/app/cert-manager
        property: dns_api_token
```

---

## 4. Deploying Cert-Manager

We will install Cert-Manager using the official Jetstack Helm chart.

### Step 4.1: Add Helm Repository
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### Step 4.2: Helm Values (`k8s/cert-manager-values.yaml`)
To automatically install the Custom Resource Definitions (CRDs) needed by Cert-Manager:

```yaml
installCRDs: true
```

---

## 5. Configure ClusterIssuer (`k8s/cert-manager-issuers.yaml`)

We will create a `ClusterIssuer` pointing to Let's Encrypt's ACME directory.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: admin@chalko.com  # Replace with your email address
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            email: admin@chalko.com
            apiTokenSecretRef:
              name: cert-manager-dns-token
              key: api-token
```

---

## 6. Secure Gitea Ingress

Once the ClusterIssuer is active, update the Gitea ingress in [k8s/gitea-values.yaml](file:///home/nick/src/fog/k8s/gitea-values.yaml) to request a certificate:

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Tells Cert-Manager to issue certificate
  hosts:
    - host: gitea.fog.lodge.chalko.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - gitea.fog.lodge.chalko.com
      secretName: gitea-tls
```

---

## 7. Execution Roadmap

1. **Populate DNS API token** inside Vault.
2. **Install Cert-Manager via Helm**:
   ```bash
   helm install cert-manager jetstack/cert-manager \
       -f k8s/cert-manager-values.yaml \
       -n cert-manager \
       --create-namespace
   ```
3. **Apply the secrets synchronization**:
   ```bash
   kubectl apply -f k8s/cert-manager-secrets.yaml
   ```
4. **Apply ClusterIssuer**:
   ```bash
   kubectl apply -f k8s/cert-manager-issuers.yaml
   ```
5. **Update Gitea Helm upgrade** with the ingress TLS annotations enabled.
