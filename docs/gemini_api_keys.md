# Google Gemini API Key & GCP Project Documentation

This document explains the origins and configurations of the Google Gemini API Key (`GEMINI_API_KEY`) used inside the `fog` homelab and LiteLLM configurations.

---

## 1. Credentials Location in Homelab

In the `fog` repository, API keys are stored centrally in **HashiCorp Vault** (under `secret/data/app/litellm` in K8s, property `gemini_api_key`). 
The keys are synced automatically into the Kubernetes namespace via the External Secrets Operator (ESO) as the `litellm-secrets` Kubernetes Secret.

---

## 2. Key Origin & Google Cloud Platform (GCP) Context

The Gemini API Key (`GEMINI_API_KEY`) is generated via **Google AI Studio** and is associated with the following Google Cloud environment:

*   **Google Account Owner**: `nick@chalko.com`
*   **Active GCP Project**: `lodge-network` (used for local systems and resource integrations)
*   **Alternative GCP DNS Project**: `gddns-1041` (used strictly for CloudDNS API letsencrypt solvers)

The value starting with `AQ.Ab8RN6...` is a standard Google AI Studio API key used directly with Gemini's Developer API endpoints.

---

## 3. Excluded Providers

*   **Anthropic**: There is **no** active Anthropic/Claude integration or credentials configured in this repository. All fallbacks and high-reasoning tasks route exclusively through Gemini models (e.g. `gemini-3.5-pro` and `gemini-3.5-flash`) or xAI (`grok-2` / `grok-beta`).
