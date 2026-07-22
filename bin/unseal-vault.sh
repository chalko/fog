#!/usr/bin/env bash
# Script to unseal HashiCorp Vault using keys retrieved from password-store.
# This requires sourcing the Vault environment variables first.

VAULT_ENV="/dev/shm/fog/vault-secret.env"

if [ -f "$VAULT_ENV" ]; then
    echo "Loading Vault environment from $VAULT_ENV..."
    source "$VAULT_ENV"
else
    echo "Error: Vault environment cache not found at $VAULT_ENV."
    echo "Please run: source bin/load-env.sh"
    exit 1
fi

echo "=========================================================="
echo "Unsealing HashiCorp Vault (requires 3 key shares)"
echo "You will need to tap your YubiKey up to 3 times."
echo "=========================================================="

for i in {1..3}; do
    echo "Retrieving and applying unseal key $i/3..."
    key=$(pass show "fog/vault/unseal_key_${i}" 2>/dev/null)
    if [ -z "$key" ]; then
        echo "Error: Failed to retrieve unseal_key_${i} from pass."
        exit 1
    fi
    vault operator unseal "$key"
done

echo "Vault unseal sequence complete."
