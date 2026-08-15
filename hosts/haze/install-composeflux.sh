#!/usr/bin/env bash
# ==============================================================================
# haze - ComposeFlux Agent Installer for ASUS Ascent GX10
# ==============================================================================
# Installs and configures ComposeFlux agent, systemd unit, and secret retrieval.
# ==============================================================================

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
COMPOSEFLUX_VERSION="${COMPOSEFLUX_VERSION:-v0.4.2}"
TARGET_DIR="/opt/composeflux"
CONFIG_DIR="/etc/composeflux"
SCRIPTS_DIR="/opt/composeflux/scripts"
STACKS_DIR="/opt/composeflux/stacks/haze"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo "==> [installer] $*"
}

if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" != "true" ]; then
  echo "ERROR: This installation script must be run as root (or with DRY_RUN=true)." >&2
  exit 1
fi

log "Target Host: haze (ASUS Ascent GX10 - ARM64)"
log "Installation Mode: $([ "$DRY_RUN" = "true" ] && echo 'DRY-RUN (Simulated)' || echo 'LIVE EXECUTION')"

# 1. Dependency Validation
log "Checking required system dependencies..."
for cmd in docker curl jq git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [✓] $cmd: found ($(command -v "$cmd"))"
  else
    echo "  [✗] $cmd: NOT found"
    if [ "$DRY_RUN" != "true" ]; then
      echo "Please install $cmd before running installer." >&2
      exit 1
    fi
  fi
done

# Check Docker Compose plugin
if docker compose version >/dev/null 2>&1; then
  echo "  [✓] docker compose: available"
else
  echo "  [✗] docker compose plugin not found"
  if [ "$DRY_RUN" != "true" ]; then
    exit 1
  fi
fi

if [ "$DRY_RUN" = "true" ]; then
  log "[DRY-RUN] Directory creation: $TARGET_DIR, $CONFIG_DIR, $SCRIPTS_DIR, $STACKS_DIR"
  log "[DRY-RUN] Install binary: /usr/local/bin/composeflux ($COMPOSEFLUX_VERSION)"
  log "[DRY-RUN] Copy compose definition: $SCRIPT_ROOT/compose.yaml -> $STACKS_DIR/compose.yaml"
  log "[DRY-RUN] Copy secret fetcher: $SCRIPT_ROOT/fetch-vault-secrets.sh -> $SCRIPTS_DIR/fetch-vault-secrets.sh"
  log "[DRY-RUN] Install systemd service: $SCRIPT_ROOT/composeflux.service -> $SYSTEMD_DIR/composeflux.service"
  log "[DRY-RUN] Verification complete. Exiting without changes."
  exit 0
fi

# 2. Directory Setup
log "Creating ComposeFlux directory structure..."
mkdir -p "$TARGET_DIR" "$CONFIG_DIR" "$SCRIPTS_DIR" "$STACKS_DIR" "/var/cache/huggingface"

# 3. Copy Stack & Scripts
log "Deploying stack manifests and scripts..."
cp "$SCRIPT_ROOT/compose.yaml" "$STACKS_DIR/compose.yaml"
cp "$SCRIPT_ROOT/composeflux.yaml" "$CONFIG_DIR/composeflux.yaml"
cp "$SCRIPT_ROOT/fetch-vault-secrets.sh" "$SCRIPTS_DIR/fetch-vault-secrets.sh"
chmod +x "$SCRIPTS_DIR/fetch-vault-secrets.sh"

# 4. Install Default Agent Config
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
  cat <<EOF > "$CONFIG_DIR/config.yaml"
# ComposeFlux Agent Configuration for haze
host: haze.lodge.chalko.com
interval: 300s
stacks_dir: /opt/composeflux/stacks
sync:
  repository: https://gitea.fog.chalko.com/fog/fog.git
  branch: main
  path: hosts/haze
webhook:
  enabled: true
  port: 9898
  path: /webhook/gitea
  secret_file: /etc/composeflux/webhook-secret
EOF
fi

# 5. Install Systemd Service
log "Installing composeflux.service..."
cp "$SCRIPT_ROOT/composeflux.service" "$SYSTEMD_DIR/composeflux.service"
systemctl daemon-reload

log "ComposeFlux packaging and installation preparation complete!"
log "Note: To enable service, run 'systemctl enable --now composeflux.service' after secret configuration."
