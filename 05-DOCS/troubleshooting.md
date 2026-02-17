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

### Traefik certificate errors
1. Check Traefik dashboard for certificate status
2. Verify DNS records point to correct IP
3. Review Traefik logs: `docker logs traefik`
4. Force certificate renewal if needed

### DNS not resolving
1. Verify DNS configuration at registrar
2. Check propagation: `dig subdomain.shannonjlove.cloud`
3. Confirm Traefik routing rules match subdomain

## Docker / Container Issues

### Container not starting
1. Check logs: `docker logs <container_name>`
2. Verify docker-compose.yml syntax
3. Check available disk space: `df -h`
4. Review port conflicts: `docker ps`

### Traefik not routing
1. Verify Docker labels on container
2. Check Traefik dynamic configuration
3. Restart Traefik: `docker restart traefik`

## Tailscale Issues

### Device not appearing on tailnet
1. Check status: `sudo tailscale status`
2. Reconnect: `sudo tailscale up --ssh`
3. Run diagnostics: `sudo tailscale netcheck`

---
*Last updated: February 2026*