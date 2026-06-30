# AI MCP Servers

Model Context Protocol server containers for automated infrastructure management.

## Services

### mcp-server-oci

MCP server for Oracle Cloud Infrastructure ([jopsis/mcp-server-oci](https://github.com/jopsis/mcp-server-oci)).
Provides 85+ tools covering Compute, Databases, Networking, Storage, Kubernetes, IAM, Security, Cost, and Monitoring.

**Files:**
- `Dockerfile.mcp-oci` — builds the mcp-server-oci image
- `docker-compose.yml` — standalone service definition

**Usage on Hostinger Nexus:**
```bash
# Build image
docker compose build mcp-server-oci

# Start (keeps container alive; Claude exec's into it for stdio sessions)
docker compose up -d mcp-server-oci

# Claude Code ~/.claude/claude.json entry
{
  "mcpServers": {
    "mcp-server-oci": {
      "command": "docker",
      "args": ["exec", "-i", "mcp-server-oci",
               "python", "-m", "mcp_server_oci.mcp_server", "--profile", "DEFAULT"],
      "env": { "FASTMCP_LOG_LEVEL": "INFO" }
    }
  }
}
```

**OCI credentials** are mounted from `$OCI_CONFIG_DIR` (default `~/.oci`) read-only. Never bake secrets into the image.

## Deployment Matrix

| Environment | Method | Config |
|---|---|---|
| Hostinger Nexus | Docker container (this dir) | `docker exec` stdio |
| Oracle sOs | systemd service | `01-DEPLOYMENT/oracle/` |
| WebTop | installed inside container | `02-CONTAINERS/webtop/` |

---
*No real credentials or private server details should be stored here.*
