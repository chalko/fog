# Hermes Agent Setup & Configuration

This document tracks the deployment and configuration details of the **Nous Research Hermes Agent** in the home lab Kubernetes cluster.

## Deployment Details

- **Namespace**: `hermes`
- **Deployment Manifest Location**: [`apps/base/hermes/`](file:///home/nick/src/fog/apps/base/hermes/)
- **Helm Chart**: [`ultraworkers/hermes-agent-helm-chart`](https://github.com/ultraworkers/hermes-agent-helm-chart.git)
- **Docker Image**: `nousresearch/hermes-agent:latest`
- **Default Port**: `8642` (exposed internally as a ClusterIP service on port `80` and externally via Nginx Ingress)

## Network Access

- **Internal Service URL**: `http://hermes-hermes-agent.hermes.svc.cluster.local:80`
- **External Ingress URL**: `https://hermes.fog.chalko.com`
- **SSL/TLS**: Secured using `cert-manager` via Let's Encrypt production certificates (`letsencrypt-prod`).

## LLM Integration

Hermes Agent is configured to route all LLM requests internally through the local LiteLLM proxy:
- **Base URL**: `http://litellm.litellm.svc.cluster.local:4000/v1`
- **API Key**: Managed dynamically via HashiCorp Vault.

## Secrets Management

Secrets are managed using the **External Secrets Operator (ESO)** and synced automatically from HashiCorp Vault:
- **K8s Secret Name**: `hermes-secrets`
- **Vault Secret Path**: `secret/data/app/litellm`
- **Keys Synced**:
  - `openai-api-key`: Resolves from Vault property `master_key` to connect to LiteLLM.
  - `API_SERVER_KEY`: Resolves from Vault property `master_key` to protect the Hermes API endpoint.

## Security Context & Pod Security Admission (PSA)

To run the `nousresearch/hermes-agent` image (which uses the `s6-overlay` process supervisor) within our cluster, the following configuration was applied:
1. **Namespace Privilege Label**: The `hermes` namespace is labeled with `pod-security.kubernetes.io/enforce: privileged` to permit running the container as root (`UID 0`) initially.
2. **Linux Capabilities**: The container `securityContext` is granted `CHOWN`, `SETUID`, `SETGID`, and `DAC_OVERRIDE` capabilities to allow `s6-overlay` to initialize, manage ownership, and drop privileges to the non-root `hermes` user (UID 10000) during boot.
3. **Writeable /run**: An `emptyDir` memory volume is mounted at `/run` to allow s6-overlay's initialization processes to write service files.

## Resources Allocation

- **Requests**: `500m` CPU / `1Gi` Memory
- **Limits**: `2` CPU / `4Gi` Memory
- **Persistent Storage**: `10Gi` PVC (`local-path` storage class) mounted at `/opt/data`
