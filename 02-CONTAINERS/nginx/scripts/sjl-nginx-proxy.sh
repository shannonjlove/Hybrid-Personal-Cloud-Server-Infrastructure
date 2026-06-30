#!/bin/bash
# sjl-nginx-proxy.sh — Manage nginx reverse-proxy configs on the Oracle sOs VM.
#
# Usage:
#   sjl-nginx-proxy.sh add    <name> <upstream> [--domain <fqdn>] [--ssl]
#   sjl-nginx-proxy.sh update <name> <new-upstream> [--domain <fqdn>]
#   sjl-nginx-proxy.sh remove <name>
#   sjl-nginx-proxy.sh list
#   sjl-nginx-proxy.sh reload
#   sjl-nginx-proxy.sh check
#
# <upstream> format: host:port  (e.g. 127.0.0.1:3000)
# <name>     is the short service identifier (e.g. webtop, jellyfin)
# --domain   sets the server_name; defaults to <name>.shannonjlove.cloud
# --ssl      requests a Let's Encrypt certificate via certbot after writing config
#
# Examples:
#   sjl-nginx-proxy.sh add webtop 127.0.0.1:3000 --ssl
#   sjl-nginx-proxy.sh update webtop 127.0.0.1:3001
#   sjl-nginx-proxy.sh remove webtop
#   sjl-nginx-proxy.sh list

set -euo pipefail

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
TEMPLATE_HTTP="/etc/nginx/sjl-templates/proxy-http.conf"
TEMPLATE_SSL="/etc/nginx/sjl-templates/proxy-ssl.conf"
DEFAULT_DOMAIN_SUFFIX="shannonjlove.cloud"
NGINX_USER="www-data"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[$(date -u +%FT%TZ)] $*"; }

require_root() {
    [[ $EUID -eq 0 ]] || die "This script must be run as root."
}

validate_upstream() {
    local upstream="$1"
    [[ "$upstream" =~ ^[a-zA-Z0-9._-]+:[0-9]{1,5}$ ]] \
        || die "Invalid upstream format '${upstream}'. Expected host:port (e.g. 127.0.0.1:3000)."
}

validate_name() {
    local name="$1"
    [[ "$name" =~ ^[a-z0-9_-]+$ ]] \
        || die "Invalid name '${name}'. Use lowercase letters, digits, hyphens, underscores only."
}

ensure_templates() {
    if [[ ! -f "$TEMPLATE_HTTP" || ! -f "$TEMPLATE_SSL" ]]; then
        info "Installing nginx templates to /etc/nginx/sjl-templates/ ..."
        mkdir -p /etc/nginx/sjl-templates
        cp "$(dirname "$0")/../templates/proxy-http.conf" "$TEMPLATE_HTTP"
        cp "$(dirname "$0")/../templates/proxy-ssl.conf"  "$TEMPLATE_SSL"
    fi
}

config_path() { echo "${SITES_AVAILABLE}/sjl-${1}.conf"; }
enabled_path() { echo "${SITES_ENABLED}/sjl-${1}.conf"; }

# ── commands ─────────────────────────────────────────────────────────────────

cmd_add() {
    local name="" upstream="" domain="" ssl=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            --ssl)    ssl=1;        shift   ;;
            *)
                if [[ -z "$name" ]];     then name="$1";
                elif [[ -z "$upstream" ]]; then upstream="$1";
                else die "Unexpected argument: $1"; fi
                shift ;;
        esac
    done

    [[ -n "$name" && -n "$upstream" ]] || die "Usage: add <name> <upstream> [--domain <fqdn>] [--ssl]"
    validate_name "$name"
    validate_upstream "$upstream"
    domain="${domain:-${name}.${DEFAULT_DOMAIN_SUFFIX}}"

    local cfg; cfg=$(config_path "$name")
    [[ ! -f "$cfg" ]] || die "Config already exists: ${cfg}. Use 'update' to change it."

    ensure_templates

    local template="$TEMPLATE_HTTP"
    [[ $ssl -eq 1 ]] && template="$TEMPLATE_SSL"

    sed \
        -e "s|__SERVICE_NAME__|${name}|g" \
        -e "s|__DOMAIN__|${domain}|g" \
        -e "s|__UPSTREAM__|${upstream}|g" \
        "$template" > "$cfg"

    ln -sf "$cfg" "$(enabled_path "$name")"
    info "Created: ${cfg}"

    if [[ $ssl -eq 1 ]]; then
        info "Requesting Let's Encrypt certificate for ${domain} ..."
        nginx -t && systemctl reload nginx
        certbot --nginx -d "$domain" --non-interactive --agree-tos \
            --email "sjlove@shannonjeffreylove.com" --redirect \
            || die "certbot failed — check DNS for ${domain} resolves to this server."
        info "SSL certificate installed for ${domain}."
    else
        cmd_reload
    fi

    info "Done. Proxy active: ${domain} → ${upstream}"
}

cmd_update() {
    local name="" upstream="" domain=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            *)
                if [[ -z "$name" ]];     then name="$1";
                elif [[ -z "$upstream" ]]; then upstream="$1";
                else die "Unexpected argument: $1"; fi
                shift ;;
        esac
    done

    [[ -n "$name" && -n "$upstream" ]] || die "Usage: update <name> <new-upstream> [--domain <fqdn>]"
    validate_name "$name"
    validate_upstream "$upstream"

    local cfg; cfg=$(config_path "$name")
    [[ -f "$cfg" ]] || die "No config found for '${name}'. Use 'add' first."

    # Rewrite upstream line in-place; optionally update server_name too
    sed -i "s|proxy_pass http://.*|proxy_pass http://${upstream};|g" "$cfg"
    if [[ -n "$domain" ]]; then
        sed -i "s|server_name .*;|server_name ${domain};|g" "$cfg"
    fi

    info "Updated upstream for '${name}' → ${upstream}"
    cmd_reload
}

cmd_remove() {
    local name="${1:?Usage: remove <name>}"
    validate_name "$name"

    local cfg; cfg=$(config_path "$name")
    local sym; sym=$(enabled_path "$name")

    [[ -f "$cfg" ]] || die "No config found for '${name}'."

    rm -f "$sym" "$cfg"
    info "Removed config for '${name}'."
    cmd_reload
}

cmd_list() {
    echo "Active SJL nginx proxies:"
    echo "─────────────────────────────────────────────────────"
    local found=0
    for cfg in "${SITES_AVAILABLE}"/sjl-*.conf; do
        [[ -f "$cfg" ]] || continue
        local name; name=$(basename "$cfg" .conf | sed 's/^sjl-//')
        local domain; domain=$(grep -oP '(?<=server_name )\S+(?=;)' "$cfg" 2>/dev/null | head -1 || echo "?")
        local upstream; upstream=$(grep -oP '(?<=proxy_pass http://)\S+(?=;)' "$cfg" 2>/dev/null | head -1 || echo "?")
        local enabled="disabled"
        [[ -L "$(enabled_path "$name")" ]] && enabled="enabled"
        printf "  %-20s %-35s → %-25s [%s]\n" "$name" "$domain" "$upstream" "$enabled"
        found=1
    done
    [[ $found -eq 1 ]] || echo "  (none)"
    echo "─────────────────────────────────────────────────────"
}

cmd_check() {
    nginx -t && info "nginx configuration OK."
}

cmd_reload() {
    nginx -t || die "nginx config test failed — not reloading."
    systemctl reload nginx
    info "nginx reloaded."
}

# ── dispatch ──────────────────────────────────────────────────────────────────

require_root

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    add)    cmd_add    "$@" ;;
    update) cmd_update "$@" ;;
    remove) cmd_remove "$@" ;;
    list)   cmd_list        ;;
    check)  cmd_check       ;;
    reload) cmd_reload      ;;
    help|--help|-h)
        sed -n '2,18p' "$0" | sed 's/^# \?//'
        ;;
    *) die "Unknown command '${COMMAND}'. Run with 'help' for usage." ;;
esac
