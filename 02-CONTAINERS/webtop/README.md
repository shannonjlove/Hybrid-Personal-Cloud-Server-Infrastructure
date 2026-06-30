# WebTop – Oracle VPS Browser Desktop

Browser-accessible Ubuntu KDE desktop served from the Oracle sOs VPS.

## URL

`https://desktop.shannonjlove.cloud`

## Stack

| Component | Detail |
|-----------|--------|
| Image | `lscr.io/linuxserver/webtop:ubuntu-kde` |
| Auth | Traefik BasicAuth (bcrypt) |
| TLS | Let's Encrypt via Traefik |
| Port (internal) | 3000 (HTTP), 3001 (HTTPS) |

## Deploy

```bash
# From your local machine — runs on the Oracle VPS
ssh ubuntu@150.136.77.26 'bash -s' < 01-DEPLOYMENT/oracle/install-webtop.sh
```

Or manually on the VPS:

```bash
cd ~/Hybrid-Personal-Cloud-Server-Infrastructure/02-CONTAINERS/webtop
cp .env.example .env   # edit WEBTOP_AUTH_USERS
docker compose up -d
```

## Generating BasicAuth credentials

```bash
# Install htpasswd (apache2-utils) if needed
sudo apt-get install -y apache2-utils

# Generate — double the $ signs for docker-compose env substitution
echo $(htpasswd -nB admin) | sed -e 's/\$/\$\$/g'
```

Paste the output as the value of `WEBTOP_AUTH_USERS` in `.env`.

## tag command (jdberry/tag-compatible)

On first container start, `custom-cont-init.d/10-install-tag.sh` runs and:

1. Installs `attr` (provides `setfattr` / `getfattr`)
2. Clones [jdberry/tag](https://github.com/jdberry/tag) to `/opt/jdberry-tag` for reference
3. Installs a Python xattr wrapper at `/usr/local/bin/tag` with the same CLI surface

```bash
# Inside WebTop terminal
tag add "Project,Green" ~/Desktop/myfile.pdf
tag list ~/Desktop/myfile.pdf
tag find Project
tag remove "Green" ~/Desktop/myfile.pdf
tag clear ~/Desktop/myfile.pdf
```

Tags are stored as `user.tag` extended attributes — portable across any Linux filesystem that supports xattr (ext4, btrfs, xfs, etc.).

### macOS side

On macOS, install the real `jdberry/tag` via Homebrew:

```bash
brew install tag
# or build from source:
bash 03-AUTOMATION/auto-tagging/install-tag.sh
```

The CLI surface is identical, so automation scripts work on both sides.

## Volumes

| Volume | Purpose |
|--------|---------|
| `webtop-config` | KDE config, app state |
| `~/webtop-home` (host) | Mounted to `/config/Desktop` inside container |

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TZ` | No | Timezone (default: America/Los_Angeles) |
| `WEBTOP_AUTH_USERS` | Yes | BasicAuth user:bcrypt-hash pairs |
