---
name: composeflux
description: |
  Declarative GitOps workflow and operational rules for managing Docker Compose stacks with ComposeFlux.
  Use whenever deploying, updating, or managing container stacks on edge/Docker hosts without ad-hoc SSH modifications.
---

# ComposeFlux Operational Skill

ComposeFlux is the declarative GitOps automation engine for Docker Compose stacks across infrastructure nodes (such as the `haze` AI inference workstation).

---

## Core Principles

1. **Git as Single Source of Truth**:
   - All container configurations, environment flags, and resources are defined strictly in Git (e.g. `hosts/<hostname>/compose.yaml` and `hosts/<hostname>/composeflux.yaml`).
   - Never make manual, out-of-band modifications on the target hosts.

2. **No Ad-Hoc SSH Container Mutations**:
   - Do NOT run manual container lifecycle commands (`docker run`, `docker restart`, `docker compose up`, `docker stop`, `docker rm`) via interactive SSH sessions to experiment or deploy.
   - Ad-hoc modifications break GitOps state reconciliation, cause configuration drift, and disrupt running container lifecycles.

3. **Automated Reconciliation**:
   - ComposeFlux reconciles state either automatically via periodic polling intervals or instantly via Gitea push webhooks.
   - Changes are deployed by pushing commits to `main` on the central Gitea repository.

---

## Standard Workflow

### 1. Edit Declarative Stack Manifest
Edit the service configuration in `hosts/<host>/compose.yaml`:
```yaml
services:
  vllm-qwen38:
    image: vllm/vllm-openai:latest
    ...
```

### 2. Commit and Push to Git
```bash
git add hosts/<host>/compose.yaml
git commit -m "feat(<host>): update stack configuration"
git push origin main
```

### 3. Webhook Trigger (Optional Immediate Sync)
If instant reconciliation is desired without waiting for the next polling cycle, trigger the ComposeFlux webhook receiver:
```bash
curl -s -X POST http://<host-ip>:9898/webhook/gitea || true
```

### 4. Zero-SSH Observability & Health Verification
Verify service health purely through published HTTP endpoints and API health checks:
```bash
# Check stack health
curl -s http://<host-ip>:8000/health

# Check model readiness
curl -s http://<host-ip>:8000/v1/models
```
