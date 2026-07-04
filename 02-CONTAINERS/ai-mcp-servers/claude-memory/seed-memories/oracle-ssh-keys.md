# SJL Oracle SSH Key Layout

## Status
Recorded from ChatGPT session — paths and fingerprints have not been
independently revalidated via live filesystem inspection.

## Primary Oracle VM SSH Key
| Field | Value |
|---|---|
| Private key | `/home/sjl/.ssh/id_ed25519_oracle` |
| Public key | `/home/sjl/.ssh/id_ed25519_oracle.pub` |
| Fingerprint | `SHA256:hWCObgU2s333ojLvYqqzW+gy/I1kXMF8WkUdMcMMOVQ` |
| Host | `100.67.229.94` (sOs Tailscale IP) |
| User | `ubuntu` |

SSH command: `ssh -i /home/sjl/.ssh/id_ed25519_oracle ubuntu@100.67.229.94`

## SJL Unified Cloud MCP SSH Bridge Key
| Field | Value |
|---|---|
| Private key | `/opt/secrets/oracle/id_rsa` |
| Fingerprint | `SHA256:huNcak2mC88jm7JPxtWYnkLsPNbUxgs9rrQQAJ5zE5I` |
| Purpose | SSH bridge used by the SJL Unified Cloud MCP connector |

## OCI API Key (not an SSH key)
Used for Oracle Cloud Infrastructure API requests only.
Commonly named `oci_api_key.pem`. Cannot substitute for SSH login.

## Recommended SSH Config Entry
```
Host oracle-sjl
    HostName 100.67.229.94
    User ubuntu
    IdentityFile /home/sjl/.ssh/id_ed25519_oracle
    IdentitiesOnly yes
```
Connect with: `ssh oracle-sjl`

## Security Notes
- Never place private-key contents in docs, chat, source control, or BookStack
- Store only paths, public fingerprints, host aliases, rotation metadata
- `chmod 600 <private-key>` always
- Verify fingerprint: `ssh-keygen -lf <public-key-path>`
- Root SSH login must stay disabled; connect as `ubuntu` or `sjl`, elevate with `sudo`
