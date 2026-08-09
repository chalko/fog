# Deployment Plan: Dolt SQL Server on Kubernetes via FluxCD

This document details the plan to deploy **Dolt** (the version-controlled SQL database) on the `fog` Kubernetes cluster using **FluxCD**, **HashiCorp Vault**, **External Secrets Operator (ESO)**, and **NGINX Ingress TCP Forwarding** under the domain `dolt.fog.chalko.com:3306`.

---

## 1. Architectural Overview

| Component | Choice / Setting | Rationale |
| :--- | :--- | :--- |
| **Namespace** | `dolt` | Dedicated namespace for Dolt database resources. |
| **Workload Type** | `StatefulSet` | Ensures stable network identity and persistent volume binding for database storage. |
| **Container Image** | `dolthub/dolt-sql-server:2.2.3` | Hardcoded explicit version of Dolt SQL Server for reproducible GitOps deployments. |
| **Database Port** | `3306` | Default MySQL-compatible wire protocol port. |
| **Domain & Ingress** | `dolt.fog.chalko.com:3306` | External DNS registers `dolt.fog.chalko.com`. NGINX Ingress forwards TCP port 3306 to `dolt/dolt:3306`. |
| **Data Storage** | `PersistentVolumeClaim` (10Gi, `local-path` storage class) | Mounted at `/var/lib/dolt` inside the container for database persistence. |
| **Secrets Engine** | HashiCorp Vault (`secret/data/app/dolt`) | Centralized secret storage for root password (`root_password`). |
| **Secret Syncing** | External Secrets Operator (`ExternalSecret`) | Syncs Vault secret into K8s Secret `dolt-secrets`. |
| **GitOps Tracking** | FluxCD (`apps/base/dolt` & `infrastructure/base/ingress-nginx`) | Automatically reconciled by Flux. |

---

## 2. Directory Structure & Files to Modify / Create

### New Files under `apps/base/dolt/`:
```
apps/base/dolt/
├── namespace.yaml      # Creates 'dolt' namespace and ServiceAccount
├── secrets.yaml        # ExternalSecret referencing Vault secret/data/app/dolt
├── service.yaml        # ClusterIP service exposing port 3306
├── statefulset.yaml    # StatefulSet deployment for Dolt SQL server
├── ingress.yaml        # Ingress manifest for dolt.fog.chalko.com (ExternalDNS & TLS)
└── kustomization.yaml  # Kustomization manifest for apps/base/dolt
```

### Modified Infrastructure Files:
- `infrastructure/base/ingress-nginx/ingress-nginx.yaml`: Configure TCP port 3306 forwarding to `dolt/dolt:3306`.
- `apps/base/kustomization.yaml`: Register `- dolt`.

---

## 3. Detailed File Specifications

### 3.1 `apps/base/dolt/namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dolt
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: dolt
```

### 3.2 `apps/base/dolt/secrets.yaml`
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: dolt-secrets
  namespace: dolt
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: dolt-secrets
    creationPolicy: Owner
  data:
    - secretKey: root-password
      remoteRef:
        key: secret/data/app/dolt
        property: root_password
```

### 3.3 `apps/base/dolt/statefulset.yaml`
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: dolt
  namespace: dolt
  labels:
    app.kubernetes.io/name: dolt
spec:
  serviceName: dolt
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: dolt
  template:
    metadata:
      labels:
        app.kubernetes.io/name: dolt
    spec:
      containers:
        - name: dolt
          image: dolthub/dolt-sql-server:2.2.3
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3306
              name: mysql
          env:
            - name: DOLT_ROOT_HOST
              value: "%"
            - name: DOLT_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: dolt-secrets
                  key: root-password
          volumeMounts:
            - name: dolt-data
              mountPath: /var/lib/dolt
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "2000m"
              memory: "2Gi"
  volumeClaimTemplates:
    - metadata:
        name: dolt-data
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: "local-path"
        resources:
          requests:
            storage: 10Gi
```

### 3.4 `apps/base/dolt/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: dolt
  namespace: dolt
  labels:
    app.kubernetes.io/name: dolt
spec:
  type: ClusterIP
  ports:
    - port: 3306
      targetPort: 3306
      name: mysql
  selector:
    app.kubernetes.io/name: dolt
```

### 3.5 `apps/base/dolt/ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dolt
  namespace: dolt
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  rules:
    - host: dolt.fog.chalko.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: dolt
                port:
                  number: 3306
  tls:
    - hosts:
        - dolt.fog.chalko.com
      secretName: dolt-tls
```

### 3.6 `apps/base/dolt/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - secrets.yaml
  - service.yaml
  - statefulset.yaml
  - ingress.yaml
```

### 3.7 NGINX Ingress TCP Forwarding Configuration (`infrastructure/base/ingress-nginx/ingress-nginx.yaml`)
Update the `ingress-nginx` HelmRelease to forward TCP port 3306:
```diff
   values:
     controller:
       hostNetwork: true
       dnsPolicy: ClusterFirstWithHostNet
       kind: DaemonSet
       service:
         type: ClusterIP
       publishService:
         enabled: false
+    tcp:
+      3306: "dolt/dolt:3306"
```

---

## 4. Execution Roadmap & Steps

1. **Populate Secrets in Vault**:
   Store the root password in Vault under `secret/data/app/dolt`:
   ```bash
   vault kv put secret/app/dolt root_password="<SECURE_ROOT_PASSWORD>"
   ```

2. **Create K8s Manifests in Git**:
   Write `apps/base/dolt/*` files, update `apps/base/kustomization.yaml`, and update `infrastructure/base/ingress-nginx/ingress-nginx.yaml`.

3. **Reconcile FluxCD**:
   Force Flux to reconcile infrastructure and apps:
   ```bash
   flux reconcile kustomization infrastructure --with-source
   flux reconcile kustomization apps --with-source
   ```

4. **Verification & Access Testing**:
   - Check pod state: `kubectl get pods -n dolt`
   - Check ExternalSecret sync: `kubectl get secret dolt-secrets -n dolt`
   - Test MySQL connection: `mysql -h dolt.fog.chalko.com -P 3306 -u root -p`

---

## 5. User Management & Access Control

Dolt is 100% MySQL-compatible for authentication and privileges. Users and permissions are created via standard MySQL SQL commands:

```sql
-- Connect as root
mysql -h dolt.fog.chalko.com -P 3306 -u root -p

-- 1. Create a new user (allows connection from any host '%')
CREATE USER 'username'@'%' IDENTIFIED BY 'user_password';

-- 2. Grant privileges on a specific database (e.g. my_database)
GRANT ALL PRIVILEGES ON `my_database`.* TO 'username'@'%';

-- 3. Grant read-only access to a database
GRANT SELECT ON `my_database`.* TO 'reader'@'%';

-- 4. Apply changes
FLUSH PRIVILEGES;
```

User credentials and grant tables are stored in Dolt's persistent volume (`/var/lib/dolt`) and remain intact across restarts.

---

## 6. Review & Feedback Request

Please review the updated plan with explicit version `dolthub/dolt-sql-server:2.2.3`. Click **Proceed** to execute!
