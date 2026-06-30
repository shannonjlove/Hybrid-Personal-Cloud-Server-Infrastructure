# Troubleshooting

Common issues and resolution steps for the hybrid cloud infrastructure.

## SSH Connection Issues

### Cannot connect to Oracle instance
1. Verify Tailscale is running: `sudo tailscale status`
2. Try direct IP: `ssh -i ~/.ssh/oracle_rsa_new ubuntu@150.136.77.26`
3. Check OCI Security List for port 22 rules
4. Verify SSH key permissions: `chmod 600 ~/.ssh/oracle_rsa_new`

### SSH key rejected
1. Confirm correct key: `oracle_rsa_new` is the PRIMARY key
2. Check `~/.ssh/authorized_keys` on the instance
3. Try fallback keys: `oci_rsa` or `oracle_ed25519`

## SSL / Certificate Issues

### NPM certificate errors
1. Open NPM admin UI: `http://nexus.shannonjlove.cloud:81`
2. Go to **SSL Certificates** → check expiry and status
3. Verify DNS records point to correct IP: `dig subdomain.shannonjlove.cloud`
4. Review NPM logs: `docker logs nginx-proxy-manager`
5. Force renewal: edit the proxy host → SSL tab → Save (triggers Let's Encrypt re-issue)

### DNS not resolving
1. Verify DNS configuration at registrar
2. Check propagation: `dig subdomain.shannonjlove.cloud`
3. Confirm NPM proxy host domain matches subdomain exactly

## Docker / Container Issues

### Container not starting
1. Check logs: `docker logs <container_name>`
2. Verify docker-compose.yml syntax
3. Check available disk space: `df -h`
4. Review port conflicts: `docker ps`

### NPM not routing
1. Open NPM admin UI → verify proxy host exists and is enabled
2. Check NPM logs: `docker logs nginx-proxy-manager`
3. Restart NPM: `docker restart nginx-proxy-manager`
4. Confirm container is running and healthy: `docker ps`

## Tailscale Issues

### Device not appearing on tailnet
1. Check status: `sudo tailscale status`
2. Reconnect: `sudo tailscale up --ssh`
3. Run diagnostics: `sudo tailscale netcheck`

---
*Last updated: February 2026*