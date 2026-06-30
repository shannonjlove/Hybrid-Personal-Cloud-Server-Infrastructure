# WebTop — Daily Configuration Backup

Host-based daily backup of the WebTop Quadlet container's persistent `/config`
volume on the Oracle sOs VM. Runs as a systemd timer completely outside the
container's lifecycle — no `podman exec` required.

## File Layout

```
02-CONTAINERS/webtop/
├── scripts/
│   └── sjl-webtop-backup.sh        # Backup script (deploy to /usr/local/sbin/)
└── systemd/
    ├── webtop-backup.service        # One-shot service unit
    └── webtop-backup.timer          # Daily timer (02:30 UTC ± 15 min)
```

## How It Works

1. `webtop-backup.timer` fires at ~02:30 UTC, activating `webtop-backup.service`.
2. The service calls `/usr/local/sbin/sjl-webtop-backup.sh` as root.
3. The script archives `/srv/sjl/300000_AREAS/390000_oracle-webtop/config` to
   `/srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/webtop-config-YYYYMMDD-HHMMSS.tar.gz`.
4. The archive is verified (`tar -tzf`) before the `.tmp` file is promoted.
5. Archives older than 7 days are automatically pruned.

## Deployment

```bash
# 1. Copy script
sudo cp scripts/sjl-webtop-backup.sh /usr/local/sbin/sjl-webtop-backup.sh
sudo chmod 0755 /usr/local/sbin/sjl-webtop-backup.sh
sudo chown root:root /usr/local/sbin/sjl-webtop-backup.sh

# 2. Install systemd units
sudo cp systemd/webtop-backup.service /etc/systemd/system/webtop-backup.service
sudo cp systemd/webtop-backup.timer   /etc/systemd/system/webtop-backup.timer

# 3. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now webtop-backup.timer
```

## Verification

```bash
# Confirm timer is active and shows next trigger time
sudo systemctl list-timers | grep webtop

# Force an immediate test run
sudo systemctl start webtop-backup.service

# Check journal output
sudo journalctl -u webtop-backup.service -n 20

# Inspect the backup directory
ls -lh /srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/

# Verify archive integrity
LATEST=$(ls -t /srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/*.tar.gz | head -1)
tar -tzf "${LATEST}" > /dev/null && echo "OK: ${LATEST}"
```

## Restore Procedure

```bash
sudo systemctl stop webtop.service
sudo rm -rf /srv/sjl/300000_AREAS/390000_oracle-webtop/config

# Replace YYYYMMDD-HHMMSS with the desired snapshot
sudo tar -xzf /srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/webtop-config-YYYYMMDD-HHMMSS.tar.gz \
    -C /srv/sjl/300000_AREAS/390000_oracle-webtop/

# Re-apply ownership to match PUID/PGID from /etc/sjl/webtop/webtop.env
sudo chown -R <PUID>:<PGID> /srv/sjl/300000_AREAS/390000_oracle-webtop/config

sudo systemctl start webtop.service
```

## Notes

- **Retention:** 7 days by default. Increase `RETENTION_DAYS` in the script for
  longer history if disk allows.
- **Cache exclusions:** `.cache`, `.thumbnails`, and `__pycache__` are excluded
  from the archive to keep backup sizes small.
- **Hot backup:** The container keeps running during archival.
  `--warning=no-file-changed` prevents transient writes from aborting the job.
- **Atomic writes:** The script writes to `.tmp` then renames; partial archives
  never appear with a final filename.
- **Disk usage:** Monitor `/srv/sjl/500000_ARCHIVES/590000_oracle-webtop-backups/`
  with `du -sh`. Switch to `xz` compression (`-cJf`) for larger configs.

---

*No credentials or private server details are stored in this repository.*
