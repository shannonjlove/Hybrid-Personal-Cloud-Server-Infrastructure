# SJL Unified MCP Gateway

This deployment consolidates the existing SJL connector functions behind one MCP endpoint.

## Included domains

- Hostinger VPS health
- rootless Podman inventory and controlled actions
- rootless systemd user-service status and controlled actions
- Oracle Cloud identity, inventory, and allowlisted instance actions
- Google Cloud compute inventory, API enablement, and allowlisted instance actions
- BookStack page upsert
- allowlisted filesystem list, read, and atomic text write

## Security model

Write access is not global. Every mutation requires both:

1. the exact approval token stored outside the connector registration; and
2. a matching allowlist entry for the target service, container, VM, OCI instance, or filesystem root.

The installer deliberately does not expose arbitrary shell execution.

## Install

```bash
# Download from repo
curl -fsSL \
  "https://raw.githubusercontent.com/shannonjlove/Hybrid-Personal-Cloud-Server-Infrastructure/claude/mcp-webtop-reconnect-gngmmx/03-AUTOMATION/deploy-sjl-unified-mcp.sh" \
  -o /tmp/deploy-sjl-unified-mcp.sh

# Verify syntax
bash -n /tmp/deploy-sjl-unified-mcp.sh && echo "Syntax OK"

# Install
sudo bash /tmp/deploy-sjl-unified-mcp.sh
```

## Runtime files

```text
Application:    /opt/sjl-unified-mcp
Configuration:  /etc/sjl-unified-mcp/runtime.env
Secrets:        /opt/secrets/sjl-unified-mcp
Write token:    /root/.sjl-unified-mcp-write-token
Systemd unit:   sjl-unified-mcp.service
Default port:   8798 (staging alongside existing 8797)
```

## Required secure values

Restore these in `/etc/sjl-unified-mcp/runtime.env`:

```text
HOSTINGER_API_TOKEN
HOSTINGER_VPS_ID
BOOKSTACK_TOKEN_ID
BOOKSTACK_TOKEN_SECRET
```

Also place:

```text
OCI config:              /opt/secrets/oci/config
OCI API key:             path referenced by the OCI config
Google service-account:  /opt/secrets/sjl-unified-mcp/google-service-account.json
```

## Example allowlists

Use exact deployed names and IDs:

```text
ALLOWED_USER_SERVICES=webtopsjl.service,sjl-memory.service
ALLOWED_CONTAINERS=webtopsjl,memory-platform
ALLOWED_GCP_INSTANCES=us-central1-a/example-vm
ALLOWED_OCI_INSTANCES=ocid1.instance.oc1.iad.example
ALLOWED_FILE_ROOTS=/srv/sjl,/home/sjl
```

## Post-install validation

```bash
# Service status
systemctl status sjl-unified-mcp.service --no-pager

# Port listening
ss -ltnp | grep 8798

# Health check (MCP initialize + tools/list)
python3 - <<'PY'
import json, urllib.request
url = "http://127.0.0.1:8798/mcp"
init = {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"validation","version":"1.0"}}}
req = urllib.request.Request(url, data=json.dumps(init).encode(), headers={"Content-Type":"application/json","Accept":"application/json, text/event-stream"}, method="POST")
with urllib.request.urlopen(req, timeout=15) as r:
    sid = r.headers.get("Mcp-Session-Id","")
    r.read()
req2 = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}).encode(), headers={"Content-Type":"application/json","Accept":"application/json, text/event-stream","Mcp-Session-Id":sid}, method="POST")
with urllib.request.urlopen(req2, timeout=15) as r:
    body = r.read().decode()
names = [l.split('"')[1] for l in body.splitlines() if '"name"' in l]
print(f"Tools on 8798: {names}")
print(f"Count: {len(names)}")
PY
```

## Connector migration

After the gateway passes health checks:

1. Deploy and validate the gateway on staging port `8798` while the current service remains on `8797`.
2. Point the ChatGPT `SJL Unified Cloud MCP V2` registration to the new streamable HTTP MCP endpoint.
3. Validate read tools and one harmless controlled write (`gateway_health`).
4. Stop and disable the old service on port `8797`.
5. Optionally move the unified service from `8798` to `8797`, or retain `8798` and update the reverse proxy.
6. Remove the duplicate `SJL Unified Cloud MCP` registration.
7. Remove the standalone `SJL Oracle MCP` registration.
8. Keep the old service files backed up until rollback is no longer needed.

## Important

The script creates the unified server and write-control framework. It cannot infer missing secrets,
actual OCI instance OCIDs, GCP instance names, or approved Podman/systemd targets. All `ALLOWED_*`
lists must be populated before write tools will accept any request.
