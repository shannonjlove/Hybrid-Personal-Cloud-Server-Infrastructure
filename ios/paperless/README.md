# Paperless-NGX iOS Integration

iOS access to Paperless-NGX via [Scriptable](https://scriptable.app) — a free JavaScript automation app.

---

## Scripts

| File | Purpose |
|------|---------|
| `Paperless.js` | Full app: browse, search, upload, tag navigation. Also works as a home screen widget. |
| `PaperlessWidget.js` | Standalone widget (small / medium / large). |
| `PaperlessUpload.js` | Quick-capture upload script. Called from Shortcuts.app or standalone. |

---

## Setup

### 1 — Install Scriptable

Download **Scriptable** (free) from the App Store.

### 2 — Get Your API Token

1. Open https://paperless.shannonjlove.cloud in Safari
2. Log in → **Settings → API Token**
3. Copy the token

### 3 — Add Scripts to Scriptable

**Option A — iCloud Drive** (recommended):
1. Add the three `.js` files to `iCloud Drive / Scriptable /`
2. They appear automatically in Scriptable

**Option B — Manual**:
1. Open Scriptable → **+** → paste each script
2. Name them: `Paperless`, `PaperlessWidget`, `PaperlessUpload`

### 4 — First Run

1. Tap **Paperless** in Scriptable
2. A setup prompt appears — enter:
   - **Server URL**: `https://paperless.shannonjlove.cloud`
   - **API Token**: (from step 2)
3. Credentials are stored securely in iOS Keychain — enter once only

---

## Home Screen Widgets

### Paperless.js (combined app + widget)

1. Long-press home screen → **+** → search **Scriptable**
2. Pick **small**, **medium**, or **large**
3. Tap the widget → **Script** → select `Paperless`
4. Tapping the widget opens the Paperless web UI

### PaperlessWidget.js (dedicated widget)

Same as above but select `PaperlessWidget`.  
Supports all three sizes with different layouts:
- **Small**: total count + icon
- **Medium**: recent documents list
- **Large**: stats + recent docs + top tags

---

## iOS Shortcuts Integration

### Scan → Upload to Paperless

```
New Shortcut:
  1. [Scan Document]
     → Variable: "Scanned Doc"
  2. [Run Script: PaperlessUpload]
     → Input: Scanned Doc (passes image to the script)
```

### Pick File → Upload to Paperless

```
New Shortcut:
  1. [Get File]  (from Files.app)
  2. [Run Script: PaperlessUpload]
     → Input: File
```

### Quick Access via Back Tap / Action Button

1. **Settings → Accessibility → Touch → Back Tap** → Double Tap → **Run Shortcut: Upload to Paperless**
2. Or: **Settings → Action Button** → **Shortcut** → select the upload shortcut

---

## Upload Methods

From within the Paperless app (`Paperless.js`):
- **Upload → Files**: opens Files.app picker (PDF, images, Office docs)
- **Upload → Photos**: opens photo library picker

From `PaperlessUpload.js`:
- **Standalone**: shows same File / Photo picker
- **Via Shortcuts** with file input: uploads the file silently and returns a result string
- **Via Shortcuts** with image input: converts to PNG and uploads

---

## Tailscale Access (on the Go)

When off your home network, access Paperless via Tailscale:
- Ensure Tailscale is running on your iPhone (`shajes-iphone` in the tailnet)
- The Tailscale URL for the Nexus VPS is `nexus.shannonjlove.cloud` — or use the Tailscale IP directly
- The Scriptable scripts use the public URL (`https://paperless.shannonjlove.cloud`) which routes through Traefik with SSL

---

## Credentials Storage

All credentials are stored in **iOS Keychain** (not in the script files).  
Keys used:
- `paperless_ngx_url`
- `paperless_ngx_token`

To reset: open **Paperless.js** → menu → **Settings → Reset All**.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Not configured" on widget | Run `Paperless.js` once to enter credentials |
| Upload fails | Check Paperless is running: `systemctl status paperless.service` |
| Can't reach server | Verify DNS A record and Traefik are up; check Tailscale |
| Wrong token | Settings → Change Token in the script menu |
