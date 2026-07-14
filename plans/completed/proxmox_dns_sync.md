# Project Plan: `proxmox-dns-sync` Service

This document outlines the detailed architecture, directory layout, and deployment specifications for `proxmox-dns-sync` as an independent Go-based project packaged and delivered via a Helm chart.

---

## 1. Project Directory Layout

We will structure the project as a clean, standard Go module ready for version control:

```text
proxmox-dns-sync/
├── cmd/
│   └── sync/
│       └── main.go           # CLI Entrypoint
├── pkg/
│   ├── pve/
│   │   └── client.go         # Proxmox client using bpg/proxmox-go
│   └── pihole/
│       └── client.go         # Pi-hole v6 API sync operations
├── charts/
│   └── proxmox-dns-sync/     # Helm Chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── cronjob.yaml
│           ├── serviceaccount.yaml
│           └── externalsecret.yaml
├── go.mod
├── go.sum
└── Dockerfile
```

---

## 2. Go Client Implementation (`bpg/proxmox-go`)

We will use the **`github.com/bpg/proxmox-go`** library to interface with the hypervisor. 

### Key Implementation Flow:
1. **Initialize Client**: Connect using the Proxmox URL and token.
   ```go
   import "github.com/bpg/proxmox-go/proxmox"
   
   client, err := proxmox.NewClient(pveURL, proxmox.WithAPIToken(tokenID, tokenSecret), proxmox.WithInsecure())
   ```
2. **Retrieve Resources**: Fetch all running virtual machines and LXC containers.
3. **Query IPs**: Use the Proxmox client API to retrieve VM guest agent networks and LXC interfaces.
4. **Sync with Pi-hole**: Read existing DNS mappings, calculate additions/deletions, and write to Pi-hole via HTTP API.

---

## 3. Vault Secrets Configuration Guide

To avoid hardcoding secrets, credentials will reside inside **HashiCorp Vault** and sync to Kubernetes via the **External Secrets Operator (ESO)**.

### Step 3.1: Set Secrets in Vault
Run the following commands using the Vault CLI (or via Web UI) to configure the target paths:

```bash
# 1. Proxmox Read-Only API Token
# Key: token_id, token_secret
vault kv put secret/app/proxmox \
    token_id="dns-sync@pve!dns-sync-token" \
    token_secret="f9c1ebd8-f59e-4ff9-8bf4-265b75271c71"

# 2. Pi-hole API Token
# Key: password
vault kv put secret/app/pihole \
    password="1Yk1UqrLQJQeFRWDWPbc32b9fAyG5QuIjpVKtbRgqWo="
```

---

## 4. Helm Chart Specifications

The service is packaged as a Helm chart. It includes custom `ExternalSecret` definitions to automatically pull Vault values into Kubernetes.

### `values.yaml` (Default Configuration)
```yaml
image:
  repository: ghcr.io/yourusername/proxmox-dns-sync
  tag: v1.0.0
  pullPolicy: IfNotPresent

schedule: "*/5 * * * *" # Sync interval

config:
  proxmoxUrl: "https://10.7.82.10:8006/api2/json"
  piholeServer: "http://10.5.110.3"
  domainSuffix: "fog.lodge.chalko.com"
  subnets:
    - "10.7.82.0/24"
    - "10.5.110.0/24"

vault:
  clusterSecretStoreName: "vault-backend"
  proxmoxSecretPath: "secret/data/app/proxmox"
  piholeSecretPath: "secret/data/app/pihole"
```

### `templates/externalsecret.yaml`
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ include "proxmox-dns-sync.fullname" . }}-secrets
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: {{ .Values.vault.clusterSecretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ include "proxmox-dns-sync.fullname" . }}-secrets
    creationPolicy: Owner
  data:
    - secretKey: EXTERNAL_DNS_PROXMOX_TOKEN_ID
      remoteRef:
        key: {{ .Values.vault.proxmoxSecretPath }}
        property: token_id
    - secretKey: EXTERNAL_DNS_PROXMOX_TOKEN_SECRET
      remoteRef:
        key: {{ .Values.vault.proxmoxSecretPath }}
        property: token_secret
    - secretKey: EXTERNAL_DNS_PIHOLE_PASSWORD
      remoteRef:
        key: {{ .Values.vault.piholeSecretPath }}
        property: password
```

### `templates/cronjob.yaml`
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "proxmox-dns-sync.fullname" . }}
spec:
  schedule: {{ .Values.schedule | quote }}
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: {{ include "proxmox-dns-sync.serviceAccountName" . }}
          restartPolicy: OnFailure
          containers:
            - name: sync
              image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
              imagePullPolicy: {{ .Values.image.pullPolicy }}
              env:
                - name: EXTERNAL_DNS_PROXMOX_URL
                  value: {{ .Values.config.proxmoxUrl | quote }}
                - name: EXTERNAL_DNS_PIHOLE_SERVER
                  value: {{ .Values.config.piholeServer | quote }}
                - name: DOMAIN_SUFFIX
                  value: {{ .Values.config.domainSuffix | quote }}
                - name: EXTERNAL_DNS_PROXMOX_TOKEN_ID
                  valueFrom:
                    secretKeyRef:
                      name: {{ include "proxmox-dns-sync.fullname" . }}-secrets
                      key: EXTERNAL_DNS_PROXMOX_TOKEN_ID
                - name: EXTERNAL_DNS_PROXMOX_TOKEN_SECRET
                  valueFrom:
                    secretKeyRef:
                      name: {{ include "proxmox-dns-sync.fullname" . }}-secrets
                      key: EXTERNAL_DNS_PROXMOX_TOKEN_SECRET
                - name: EXTERNAL_DNS_PIHOLE_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: {{ include "proxmox-dns-sync.fullname" . }}-secrets
                      key: EXTERNAL_DNS_PIHOLE_PASSWORD
```
