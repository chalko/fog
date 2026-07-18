#!/usr/bin/env bash
# Script to populate and load environment files in /dev/shm/fog from pass.
# Sourcing this script is recommended: source bin/load-env.sh

SHM_DIR="/dev/shm/fog"
mkdir -p "$SHM_DIR"
chmod 700 "$SHM_DIR"

# List of env files to manage
ENVS=("proxmox" "docker" "k8s" "omni" "vault")

# Check if pass is installed
if ! command -v pass &> /dev/null; then
    echo "Warning: 'pass' (password-store) is not installed or not in PATH."
fi

load_env() {
    local target="$1"
    local env_file="$SHM_DIR/${target}.env"

    if [ -f "$env_file" ]; then
        echo "Loading cached $target env from $env_file"
        # shellcheck disable=SC1090
        source "$env_file"
        return
    fi

    echo "Cached env file $env_file not found. Retrieving secrets from pass..."
    touch "$env_file"
    chmod 600 "$env_file"

    case "$target" in
        proxmox)
            # Try to fetch from pass, write fallback templates if not found
            {
                url="$(pass show fog/proxmox/api_url 2>/dev/null || echo 'https://proxmox.local:8006/api2/json')"
                token_id="$(pass show fog/proxmox/api_token_id 2>/dev/null || echo 'terraform@pve!token')"
                token_secret="$(pass show fog/proxmox/api_token_secret 2>/dev/null || echo 'YOUR_SECRET')"
                
                echo "export PM_API_URL=\"$url\""
                echo "export PM_API_TOKEN_ID=\"$token_id\""
                echo "export PM_API_TOKEN_SECRET=\"$token_secret\""
                
                # Format endpoint for bpg/proxmox provider (strip trailing /api2/json if present)
                endpoint="${url%/api2/json}"
                # Ensure endpoint ends with /
                [[ "$endpoint" != */ ]] && endpoint="$endpoint/"
                
                echo "export PROXMOX_VE_ENDPOINT=\"$endpoint\""
                echo "export PROXMOX_VE_API_TOKEN=\"${token_id}=${token_secret}\""
            } > "$env_file"
            ;;
        omni)
            # Fetch Omni endpoint and service account key
            {
                endpoint="$(pass show fog/omni/api_endpoint 2>/dev/null || echo 'https://your-account.omni.siderolabs.io/')"
                key="$(pass show fog/omni/service_account_key 2>/dev/null || echo 'YOUR_OMNI_SERVICE_ACCOUNT_KEY')"
                echo "export OMNI_API_ENDPOINT=\"$endpoint\""
                echo "export OMNI_SERVICE_ACCOUNT_KEY=\"$key\""
            } > "$env_file"

            # Auto-generate the Proxmox Omni provider configuration yaml in memory (SHM)
            {
                pve_url="$(pass show fog/proxmox/api_url 2>/dev/null || echo 'https://proxmox.local:8006/api2/json')"
                pve_token_id="$(pass show fog/proxmox/api_token_id 2>/dev/null || echo 'root@pam!terraform')"
                pve_token_secret="$(pass show fog/proxmox/api_token_secret 2>/dev/null || echo 'YOUR_SECRET')"
                
                user_realm="${pve_token_id%%!*}"
                
                echo "proxmox:"
                echo "  username: \"$user_realm\""
                echo "  url: \"$pve_url\""
                echo "  tokenID: \"$pve_token_id\""
                echo "  tokenSecret: \"$pve_token_secret\""
                echo "  insecureSkipVerify: true"
            } > "$SHM_DIR/omni-config.yaml"
            chmod 600 "$SHM_DIR/omni-config.yaml"
            ;;
        docker)
            {
                docker_host="$(pass show fog/docker/host 2>/dev/null)"
                if [ -n "$docker_host" ]; then
                    echo "export DOCKER_HOST=\"$docker_host\""
                fi
            } > "$env_file"
            ;;
        k8s)
            {
                echo "export KUBECONFIG=\"$(pass show fog/k8s/kubeconfig_path 2>/dev/null || echo "$HOME/.kube/config")\""
            } > "$env_file"
            ;;
        vault)
            {
                vault_token="$(pass show fog/vault/root_token 2>/dev/null)"
                if [ -n "$vault_token" ]; then
                    echo "export VAULT_TOKEN=\"$vault_token\""
                fi
            } > "$env_file"
            ;;
    esac

    echo "Created cached env file: $env_file (permissions set to 600)"
    # shellcheck disable=SC1090
    source "$env_file"
}

for item in "${ENVS[@]}"; do
    load_env "$item"
done
