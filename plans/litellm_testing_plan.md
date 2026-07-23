# LiteLLM & Proxmox LXC Ollama Testing Plan

This plan outlines the steps to verify the local LiteLLM setup by routing request traffic to the CPU-only Ollama instance running in the Proxmox LXC at `ollama.fog.chalko.com`.

---

## 1. Prerequisites & Model Availability

We need to ensure that the correct testing model (`llama3.2:1b`) is pulled and ready on the Proxmox LXC.

### Action: Pull model on the LXC Ollama host
Run a POST request to the Ollama endpoint to download the model:
```bash
curl -sk -X POST https://ollama.fog.chalko.com/api/pull \
  -d '{"name": "llama3.2:1b"}'
```

---

## 2. Update LiteLLM Configuration

We need to update the LiteLLM configmap to target the Proxmox LXC Ollama instance instead of the in-cluster K8s service.

### Target: `apps/base/litellm/configmap.yaml`

```diff
       - model_name: llama3.2
         litellm_params:
           model: ollama/llama3.2:1b
-          api_base: http://ollama.ollama.svc.cluster.local:11434
+          api_base: https://ollama.fog.chalko.com
```

---

## 3. Apply and Verify

### Step 3.1: Apply changes to K8s
If Flux syncs automatically, wait for the sync or manually reconcile the litellm resources:
```bash
kubectl apply -f apps/base/litellm/configmap.yaml
kubectl rollout restart deployment litellm -n litellm
```

### Step 3.2: Retrieve LiteLLM master key
The master key is set via `LITELLM_MASTER_KEY` environment variable. Fetch it from the secrets or vault setup if needed to authenticate test requests.

### Step 3.3: Test routing via LiteLLM
Send a request to the external LiteLLM proxy endpoint (`llm.fog.chalko.com`) requesting `llama3.2`:
```bash
curl -k -X POST https://llm.fog.chalko.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
  -d '{
    "model": "llama3.2",
    "messages": [
      {
        "role": "user",
        "content": "Respond with the word: Success"
      }
    ]
  }'
```
