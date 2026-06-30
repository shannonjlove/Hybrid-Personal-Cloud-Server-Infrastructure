# iOS Scriptable Scripts

JavaScript automations for managing your hybrid cloud from iPhone/iPad.

## Setup

1. Install [Scriptable](https://scriptable.app) (free, App Store)
2. Copy these `.js` files into Scriptable (iCloud Drive → Scriptable, or paste directly)
3. Run `00-setup-keychain.js` once — it walks you through storing credentials securely in iOS Keychain

## Scripts

| Script | What it does |
|---|---|
| `00-setup-keychain.js` | One-time credential setup — stores NPM and memory URLs/passwords in iOS Keychain |
| `npm-manager.js` | List all NPM proxy hosts, enable/disable them, add new ones |
| `memory-query.js` | Search, browse, and store memories in ai-memory; works as a Shortcut action |
| `server-status-widget.js` | Home screen widget showing live up/down status of all services |

## iOS Shortcuts integration

`memory-query.js` accepts text input from the Shortcuts app:

1. Shortcuts → New Shortcut
2. Add action: **Text** (type what you want to remember)
3. Add action: **Run Script** → `memory-query.js`
4. Pass input as plain text → stores directly to ai-memory mid-term

## Adding the status widget

1. Long-press home screen → **+** → Scriptable → Small or Medium
2. Edit widget → Script: `server-status-widget.js`
3. Refreshes every 5 minutes automatically

## Credentials (stored in iOS Keychain)

| Key | Value |
|---|---|
| `npm.url` | `https://npm.shannonjlove.cloud` |
| `npm.url.tailscale` | `http://shannonjlove.tail179603.ts.net:81` |
| `npm.email` | `shannonjlove@mac.com` |
| `npm.password` | *(set during keychain setup)* |
| `memory.url` | `https://memory.shannonjlove.cloud` |
