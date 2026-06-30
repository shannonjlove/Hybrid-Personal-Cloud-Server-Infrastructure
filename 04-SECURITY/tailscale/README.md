# Tailscale

Secure mesh VPN connecting all infrastructure nodes.

## Tailnet

| Field | Value |
|-------|-------|
| Tailnet ID | `T1KxUdABi111CNTRL` |
| DNS name | `tail179603.ts.net` |
| Account | `shannonjlove@mac.com` |
| MagicDNS | Enabled |
| HTTPS Certs | Enabled |

## Devices

| Hostname | MagicDNS FQDN | Role |
|----------|---------------|------|
| nexus | `nexus.tail179603.ts.net` | Hostinger VPS — primary container host |
| sOs | `sos.tail179603.ts.net` | Oracle Cloud ARM — secondary |
| webtop | `webtop.tail179603.ts.net` | WebTop desktop container |
| shajes-iphone | `shajes-iphone.tail179603.ts.net` | iPhone / Working Copy |
| shannonjlove | `shannonjlove.tail179603.ts.net` | Mac |

## Configuration

- **Version**: 1.94.1
- **SSH**: Enabled (`--ssh` flag on all servers)
- **Tags**: `tag:server` (nexus, sOs), `tag:desktop` (webtop)

## HTTPS Certificates

HTTPS certs enabled — provision per-device with:
```bash
tailscale cert <hostname>.tail179603.ts.net
```
Cert files land at `/var/lib/tailscale/certs/` — symlink into nginx certs dir.

## Stow Quadlets

Each entity's Tailscale container lives in:
```
stow/<entity>/.config/containers/systemd/tailscale.container
```
All containers read `TS_AUTHKEY` from `~/.config/credentials/api-tokens.env`.

## Auth Key

Generate at login.tailscale.com/admin/settings/keys.
Store in `~/.config/credentials/api-tokens.env` as `TS_AUTHKEY=tskey-auth-...`.

---
*Auth tokens stored in stow credential store, not here.*
