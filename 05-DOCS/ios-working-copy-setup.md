# iOS Working Copy Integration

Working Copy is a Git client for iPhone/iPad. This document covers connecting it to the infrastructure for mobile development workflows.

## SSH Key Setup

Working Copy generates its own SSH keypair. The public key must be added to GitHub (or any SSH-based git remote) to allow push/pull.

**Working Copy key identifier**: `WorkingCopy@iPhone-30062026`  
**Key type**: ssh-rsa 4096

### Adding to GitHub
1. In Working Copy → Settings → SSH Keys → tap the key
2. Share/copy the public key
3. Add it at github.com → Settings → SSH and GPG keys → New SSH key

### Adding to a self-hosted server
```bash
# On the server, append the Working Copy public key:
echo "ssh-rsa AAAA...key... WorkingCopy@iPhone-30062026" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## WebDAV Server (iPhone → Desktop)

Working Copy can expose repositories as a WebDAV share so Mac/PC apps can read and write files directly.

| Setting | Value |
|---------|-------|
| Port | 8080 |
| Username | `webdav` |
| Password | stored in Working Copy app |
| URL format | `http://webdav@<iPhone-IP>:8080/` |

**Notes:**
- The server stops after 15 minutes of inactivity (security feature)
- Enable "Server Persistence" only when actively needed
- On the same local network, use the LAN IP
- Over Tailscale, use the Tailscale hostname (`shajes-iphone`) instead of the LAN IP

### Connecting via Tailscale (recommended)
Since the iPhone is enrolled in Tailscale as `shajes-iphone`, you can reach the WebDAV server from any Tailnet device without being on the same Wi-Fi:

```
http://webdav@shajes-iphone:8080/
```

## AI Configuration (Working Copy)

Working Copy supports AI-assisted commit messages using the Anthropic API.

**Settings location**: Working Copy → Settings → AI Configuration

| Setting | Value |
|---------|-------|
| Completion Service | Anthropic |
| Model | `claude-haiku-4-5-latest` |
| API Key | Enter from console.anthropic.com (never store in this repo) |

### Getting an API key
1. Go to console.anthropic.com → API Keys
2. Create a new key scoped to your use case
3. Paste it into Working Copy → Settings → AI Configuration → API Key
4. Tap "Test" to verify

> **Never commit API keys to this repository.** If a key is accidentally exposed, revoke it immediately at console.anthropic.com.

## Typical Mobile Workflow

```
iPhone (Working Copy)
    ├── Clone repo from GitHub via SSH
    ├── Edit files (WebDAV mount on Mac, or in-app editor)
    ├── AI-assisted commit message generation
    └── Push to GitHub → CI/CD pipeline on server
```

## Cloning This Repository

In Working Copy → + → Clone Repository:
- **URL**: `git@github.com:shannonjlove/hybrid-personal-cloud-server-infrastructure.git`
- **Authentication**: SSH (uses the WorkingCopy@iPhone key)

---
*See `04-SECURITY/tailscale/README.md` for Tailscale device enrollment details.*
