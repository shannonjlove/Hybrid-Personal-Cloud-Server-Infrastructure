#!/usr/bin/env bash
# Install mcp-server-oci on Oracle Cloud Ubuntu instance (sOs)
# Run as ubuntu user with sudo privileges
set -euo pipefail

REPO_URL="https://github.com/jopsis/mcp-server-oci"
INSTALL_DIR="/opt/mcp-server-oci"
SERVICE_USER="mcp-oci"
VENV="$INSTALL_DIR/.venv"

info()  { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

# --- system prerequisites ---------------------------------------------------
info "Installing system packages"
sudo apt-get update -qq
sudo apt-get install -y python3 python3-pip python3-venv git curl

python3_version=$(python3 -c 'import sys; print(sys.version_info[:2] >= (3,10))')
[[ "$python3_version" == "True" ]] || error "Python 3.10+ required (got $(python3 --version))"

# OCI CLI (skip if already present)
if ! command -v oci &>/dev/null; then
  info "Installing OCI CLI"
  curl -fsSL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh \
    | bash -s -- --accept-all-defaults
  export PATH="$HOME/bin:$PATH"
fi

# --- service user ------------------------------------------------------------
if ! id "$SERVICE_USER" &>/dev/null; then
  info "Creating service user $SERVICE_USER"
  sudo useradd -r -s /usr/sbin/nologin -d "$INSTALL_DIR" "$SERVICE_USER"
fi

# --- clone / update ----------------------------------------------------------
if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Updating existing install"
  sudo -u "$SERVICE_USER" git -C "$INSTALL_DIR" pull --ff-only
else
  info "Cloning mcp-server-oci to $INSTALL_DIR"
  sudo git clone "$REPO_URL" "$INSTALL_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
fi

# --- python environment ------------------------------------------------------
info "Setting up Python virtualenv"
sudo -u "$SERVICE_USER" python3 -m venv "$VENV"

info "Installing Python dependencies"
sudo -u "$SERVICE_USER" "$VENV/bin/pip" install --quiet --upgrade pip
sudo -u "$SERVICE_USER" "$VENV/bin/pip" install --quiet \
  "git+https://github.com/modelcontextprotocol/python-sdk.git"
sudo -u "$SERVICE_USER" "$VENV/bin/pip" install --quiet \
  "oci>=2.0.0" "fastapi>=0.100.0" "uvicorn>=0.22.0" \
  "click>=8.1.0" "pydantic>=2.0.0" "loguru>=0.7.0"
sudo -u "$SERVICE_USER" "$VENV/bin/pip" install --quiet -e "$INSTALL_DIR"

# --- systemd service ---------------------------------------------------------
info "Installing systemd service"
sudo cp "$(dirname "$0")/mcp-server-oci.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mcp-server-oci

info "Installation complete"
echo ""
echo "Next steps:"
echo "  1. Configure OCI CLI:  sudo -u $SERVICE_USER bash -c 'oci setup config'"
echo "     Place key at:       $INSTALL_DIR/.oci/oci_api_key.pem"
echo "  2. Start the service:  sudo systemctl start mcp-server-oci"
echo "  3. Check status:       sudo systemctl status mcp-server-oci"
echo ""
echo "MCP config for Claude Code (~/.claude/claude.json):"
cat <<EOF
{
  "mcpServers": {
    "mcp-server-oci": {
      "command": "$VENV/bin/python",
      "args": ["-m", "mcp_server_oci.mcp_server", "--profile", "DEFAULT"],
      "env": {
        "PYTHONPATH": "$INSTALL_DIR",
        "FASTMCP_LOG_LEVEL": "INFO"
      }
    }
  }
}
EOF
