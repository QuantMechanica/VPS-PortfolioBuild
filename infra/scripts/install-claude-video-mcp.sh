#!/usr/bin/env bash
set -euo pipefail

# Idempotent claude-video MCP server installer for VPS hosts.
# Safe to rerun: converges user/group, install dir, package state, and systemd unit.

MCP_ROOT="${MCP_ROOT:-/opt/quantmechanica/claude-video-mcp}"
SERVICE_NAME="${SERVICE_NAME:-claude-video-mcp}"
APP_USER="${APP_USER:-qm-mcp}"
APP_GROUP="${APP_GROUP:-qm-mcp}"
NODE_MAJOR="${NODE_MAJOR:-20}"
MCP_PACKAGE="${MCP_PACKAGE:-claude-video-mcp@latest}"
START_CMD="${START_CMD:-npx -y claude-video-mcp}"
HEALTHCHECK_CMD="${HEALTHCHECK_CMD:-}"
ENV_FILE="/etc/default/${SERVICE_NAME}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd systemctl
require_cmd npm
require_cmd node

if [[ "$(node -v | sed 's/^v//' | cut -d. -f1)" -lt "$NODE_MAJOR" ]]; then
  echo "Node.js ${NODE_MAJOR}+ required. Current: $(node -v)" >&2
  exit 1
fi

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  sudo useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
fi

if ! getent group "$APP_GROUP" >/dev/null 2>&1; then
  sudo groupadd --system "$APP_GROUP"
fi

sudo mkdir -p "$MCP_ROOT"
sudo chown -R "$APP_USER:$APP_GROUP" "$MCP_ROOT"

if [[ ! -f "$MCP_ROOT/package.json" ]]; then
  sudo -u "$APP_USER" bash -lc "cd '$MCP_ROOT' && npm init -y >/dev/null"
fi

# Reinstalling package is safe and converges to the desired package version/tag.
sudo -u "$APP_USER" bash -lc "cd '$MCP_ROOT' && npm install --omit=dev '$MCP_PACKAGE'"

if [[ ! -f "$ENV_FILE" ]]; then
  TMP_ENV="$(mktemp)"
  cat >"$TMP_ENV" <<'EOF'
# claude-video MCP runtime environment
# Fill required provider credentials before first production use.
# Example:
# ANTHROPIC_API_KEY=...
# YOUTUBE_API_KEY=...
EOF
  sudo cp "$TMP_ENV" "$ENV_FILE"
  sudo chmod 600 "$ENV_FILE"
  rm -f "$TMP_ENV"
fi

TMP_SERVICE="$(mktemp)"
cat >"$TMP_SERVICE" <<EOF
[Unit]
Description=claude-video MCP Server
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${MCP_ROOT}
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/bin/env bash -lc '${START_CMD}'
Restart=always
RestartSec=3
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

NEEDS_RELOAD=0
if [[ ! -f "$SERVICE_FILE" ]] || ! cmp -s "$TMP_SERVICE" "$SERVICE_FILE"; then
  sudo cp "$TMP_SERVICE" "$SERVICE_FILE"
  NEEDS_RELOAD=1
fi
rm -f "$TMP_SERVICE"

if [[ "$NEEDS_RELOAD" -eq 1 ]]; then
  sudo systemctl daemon-reload
fi

sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
sudo systemctl restart "$SERVICE_NAME"

if [[ -n "$HEALTHCHECK_CMD" ]]; then
  sudo -u "$APP_USER" bash -lc "$HEALTHCHECK_CMD"
fi

echo "claude-video MCP deploy converged."
echo "Service: ${SERVICE_NAME}"
echo "Env file: ${ENV_FILE}"
