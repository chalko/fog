#!/usr/bin/env bash
# Script to populate and load environment files in /dev/shm/fog from pass.
# Sourcing this script is recommended: source bin/load-env.sh

SHM_DIR="/dev/shm/fog"
mkdir -p "$SHM_DIR"
chmod 700 "$SHM_DIR"

# List of env files to manage
ENVS=("proxmox" "docker" "k8s")

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
                echo "export PM_API_URL=\"$(pass show fog/proxmox/api_url 2>/dev/null || echo 'https://proxmox.local:8006/api2/json')\""
                echo "export PM_API_TOKEN_ID=\"$(pass show fog/proxmox/api_token_id 2>/dev/null || echo 'terraform@pve!token')\""
                echo "export PM_API_TOKEN_SECRET=\"$(pass show fog/proxmox/api_token_secret 2>/dev/null || echo 'YOUR_SECRET')\""
            } > "$env_file"
            ;;
        docker)
            {
                echo "export DOCKER_HOST=\"$(pass show fog/docker/host 2>/dev/null || echo 'ssh://user@docker-host.local')\""
            } > "$env_file"
            ;;
        k8s)
            {
                echo "export KUBECONFIG=\"$(pass show fog/k8s/kubeconfig_path 2>/dev/null || echo "$HOME/.kube/config")\""
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
