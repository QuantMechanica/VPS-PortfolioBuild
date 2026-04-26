#!/usr/bin/env bash
set -euo pipefail

# Idempotent Paperclip deploy helper for Linux hosts.
# Safe to rerun: creates/updates desired state and restarts service only on change.

PAPERCLIP_ROOT="${PAPERCLIP_ROOT:-/opt/quantmechanica/paperclip}"
SERVICE_NAME="${SERVICE_NAME:-paperclip}"
APP_USER="${APP_USER:-paperclip}"
APP_GROUP="${APP_GROUP:-paperclip}"
NODE_MAJOR="${NODE_MAJOR:-20}"
START_CMD="${START_CMD:-npm run start}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8501/api/health}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd systemctl
require_cmd curl

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  sudo useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
fi

if ! getent group "$APP_GROUP" >/dev/null 2>&1; then
  sudo groupadd --system "$APP_GROUP"
fi

sudo mkdir -p "$PAPERCLIP_ROOT"
sudo chown -R "$APP_USER:$APP_GROUP" "$PAPERCLIP_ROOT"

if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/^v//' | cut -d. -f1)" -lt "$NODE_MAJOR" ]]; then
  echo "Node.js ${NODE_MAJOR}+ required. Install or upgrade Node before running." >&2
  exit 1
fi

if [[ -f "$PAPERCLIP_ROOT/package-lock.json" ]]; then
  sudo -u "$APP_USER" bash -lc "cd '$PAPERCLIP_ROOT' && npm ci --omit=dev"
elif [[ -f "$PAPERCLIP_ROOT/package.json" ]]; then
  sudo -u "$APP_USER" bash -lc "cd '$PAPERCLIP_ROOT' && npm install --omit=dev"
else
  echo "No package.json in $PAPERCLIP_ROOT. Copy Paperclip app first." >&2
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TMP_FILE="$(mktemp)"
cat >"$TMP_FILE" <<EOF
[Unit]
Description=Paperclip Daemon
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${PAPERCLIP_ROOT}
ExecStart=/usr/bin/env bash -lc '${START_CMD}'
Restart=always
RestartSec=3
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

NEEDS_RELOAD=0
if [[ ! -f "$SERVICE_FILE" ]] || ! cmp -s "$TMP_FILE" "$SERVICE_FILE"; then
  sudo cp "$TMP_FILE" "$SERVICE_FILE"
  NEEDS_RELOAD=1
fi
rm -f "$TMP_FILE"

if [[ "$NEEDS_RELOAD" -eq 1 ]]; then
  sudo systemctl daemon-reload
fi

sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
sudo systemctl restart "$SERVICE_NAME"

if ! curl -fsS --max-time 10 "$HEALTH_URL" >/dev/null; then
  echo "Service started but health check failed: $HEALTH_URL" >&2
  exit 1
fi

echo "Paperclip deploy converged successfully."
