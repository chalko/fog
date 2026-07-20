# Hermes Agent Setup & Configuration

This document tracks the deployment and configuration details of the **Nous Research Hermes Agent** in the home lab Kubernetes cluster.

## Deployment Details

- **Namespace**: `hermes`
- **Deployment Manifest Location**: [`apps/base/hermes/`](file:///home/nick/src/fog/apps/base/hermes/)
- **Docker Image**: `nousresearch/hermes-agent:latest` (Docker Hub)
- **Default Port**: `8642` (exposed internally as a ClusterIP service on port `80` and externally via Nginx Ingress)

## Network Access

- **Internal Service URL**: `http://hermes.hermes.svc.cluster.local:80`
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
- **Key Synced**: `openai-api-key` (resolves from Vault property `master_key`)

## Resources Allocation

- **Requests**: `100m` CPU / `256Mi` Memory
- **Limits**: `1000m` CPU / `1Gi` Memory
- **Persistent Storage**: `10Gi` PVC (`local-path` storage class) mounted at `/home/node/.hermes`
