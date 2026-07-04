// Paperless NGX — iOS Scriptable Client
// https://paperless.shannonjlove.cloud
//
// SETUP
// 1. Install Scriptable from the App Store
// 2. Create a new script and paste this file
// 3. On first run, enter your server URL and API token
//    Get token: Paperless web UI → Settings → API Token
// ─────────────────────────────────────────────────────

const KC_URL   = "paperless_ngx_url"
const KC_TOKEN = "paperless_ngx_token"

// ── Config ────────────────────────────────────────────

async function getConfig() {
  const url   = Keychain.contains(KC_URL)   ? Keychain.get(KC_URL)   : null
  const token = Keychain.contains(KC_TOKEN) ? Keychain.get(KC_TOKEN) : null
  if (!url || !token) {
    await promptSetup()
    return { url: Keychain.get(KC_URL), token: Keychain.get(KC_TOKEN) }
  }
  return { url, token }
}

async function promptSetup() {
  const a = new Alert()
  a.title = "Paperless Setup"
  a.message = "Enter your server details.\nGet API token: Web UI → Settings → API Token"
  a.addTextField("Server URL", "https://paperless.shannonjlove.cloud")
  a.addSecureField("API Token", "")
  a.addAction("Save")
  a.addCancelAction("Cancel")

  if (await a.presentAlert() === 0) {
    Keychain.set(KC_URL,   a.textFieldValue(0).replace(/\/+$/, ""))
    Keychain.set(KC_TOKEN, a.textFieldValue(1).trim())
  }
}

// ── API ───────────────────────────────────────────────

async function api(cfg, endpoint, method = "GET", body = null) {
  const req = new Request(`${cfg.url}/api/${endpoint}`)
  req.method = method
  req.headers = { "Authorization": `Token ${cfg.token}` }
  if (body) {
    req.headers["Content-Type"] = "application/json"
    req.body = JSON.stringify(body)
  }
  try { return await req.loadJSON() } catch (e) {
    console.error(`API ${method} ${endpoint}: ${e}`)
    return null
  }
}

async function postDocument(cfg, fileData, filename, mimeType) {
  const req = new Request(`${cfg.url}/api/documents/post_document/`)
  req.method = "POST"
  req.headers = { "Authorization": `Token ${cfg.token}` }
  req.addFileDataToMultipart(fileData, mimeType, "document", filename)
  try {
    await req.load()
    return true
  } catch (e) {
    console.error(`Upload failed: ${e}`)
    return false
  }
}

// ── Widget ────────────────────────────────────────────

async function buildWidget(cfg) {
  const [recent, stats] = await Promise.all([
    api(cfg, "documents/?ordering=-added&page_size=5"),
    api(cfg, "statistics/"),
  ])

  const w = new ListWidget()
  w.backgroundColor = new Color("#0d1117")
  w.setPadding(14, 16, 14, 16)
  w.url = cfg.url

  // Header row
  const hdr = w.addStack()
  hdr.layoutHorizontally()
  hdr.centerAlignContent()

  const icon = hdr.addText("📄")
  icon.font = Font.systemFont(13)
  hdr.addSpacer(6)

  const title = hdr.addText("Paperless")
  title.font = Font.boldSystemFont(14)
  title.textColor = new Color("#58a6ff")
  hdr.addSpacer()

  if (stats) {
    const count = hdr.addText(`${stats.documents_total}`)
    count.font = Font.monospacedSystemFont(12, .regular)
    count.textColor = new Color("#8b949e")
  }

  w.addSpacer(8)

  const maxItems = config.widgetFamily === "small" ? 3 : 5
  const docs = (recent?.results || []).slice(0, maxItems)

  if (docs.length === 0) {
    const empty = w.addText("No documents yet")
    empty.font = Font.systemFont(11)
    empty.textColor = new Color("#8b949e")
  } else {
    for (const doc of docs) {
      const row = w.addStack()
      row.layoutHorizontally()
      row.centerAlignContent()

      const bullet = row.addText("·")
      bullet.font = Font.systemFont(11)
      bullet.textColor = new Color("#58a6ff")
      row.addSpacer(5)

      const label = row.addText(
        doc.title.length > 32 ? doc.title.slice(0, 30) + "…" : doc.title
      )
      label.font = Font.systemFont(11)
      label.textColor = Color.white()
      label.lineLimit = 1
      w.addSpacer(3)
    }
  }

  w.addSpacer()

  const footer = w.addText(
    stats ? `${stats.documents_inbox_count} in inbox` : "Tap to open"
  )
  footer.font = Font.systemFont(9)
  footer.textColor = new Color("#484f58")

  return w
}

// ── Document Detail ───────────────────────────────────

async function showDetail(doc, cfg) {
  const lines = []
  if (doc.created)             lines.push(`Date      ${doc.created.slice(0, 10)}`)
  if (doc.correspondent_name)  lines.push(`From      ${doc.correspondent_name}`)
  if (doc.document_type_name)  lines.push(`Type      ${doc.document_type_name}`)
  if (doc.archive_serial_number) lines.push(`ASN       ${doc.archive_serial_number}`)

  const a = new Alert()
  a.title = doc.title
  a.message = lines.join("\n") || "No metadata"
  a.addAction("Open in Browser")
  a.addAction("Download to iCloud")
  a.addCancelAction("Close")

  const choice = await a.presentAlert()

  if (choice === 0) {
    Safari.open(`${cfg.url}/documents/${doc.id}/details`)
  } else if (choice === 1) {
    const req = new Request(`${cfg.url}/api/documents/${doc.id}/download/`)
    req.headers = { "Authorization": `Token ${cfg.token}` }
    const data = await req.load()
    const fm = FileManager.iCloud()
    const path = fm.joinPath(fm.documentsDirectory(), `${doc.title}.pdf`)
    fm.write(path, data)
    await alert("Downloaded", `Saved to iCloud Drive:\n${doc.title}.pdf`)
  }
}

// ── Views ─────────────────────────────────────────────

async function showDocs(cfg, endpoint, heading) {
  const data = await api(cfg, endpoint)
  if (!data?.results) { await alert("Error", "Could not load documents."); return }

  const t = new UITable()
  t.showSeparators = true

  const h = new UITableRow()
  h.isHeader = true
  h.addText(`${heading} (${data.count ?? data.results.length})`)
  t.addRow(h)

  for (const doc of data.results) {
    const r = new UITableRow()
    r.height = 58
    r.addText(doc.title, (doc.created?.slice(0, 10) ?? "—") +
      (doc.correspondent_name ? `  ·  ${doc.correspondent_name}` : ""))
    r.onSelect = async () => showDetail(doc, cfg)
    t.addRow(r)
  }

  await t.present()
}

async function showSearch(cfg) {
  const a = new Alert()
  a.title = "Search"
  a.addTextField("Full-text query…", "")
  a.addAction("Search")
  a.addCancelAction("Cancel")
  if (await a.presentAlert() !== 0) return

  const q = a.textFieldValue(0).trim()
  if (!q) return

  await showDocs(
    cfg,
    `documents/?query=${encodeURIComponent(q)}&ordering=-score&page_size=25`,
    `Results: "${q}"`
  )
}

async function showUpload(cfg) {
  const a = new Alert()
  a.title = "Upload Document"
  a.addAction("📁  Pick from Files")
  a.addAction("🖼  Pick from Photos")
  a.addCancelAction("Cancel")

  const choice = await a.presentAlert()
  if (choice === -1) return

  if (choice === 0) {
    const files = await DocumentPicker.openFile(["public.item"])
    if (!files?.length) return
    const fm   = FileManager.local()
    const data = fm.readData(files[0])
    const name = files[0].split("/").pop()
    const mime = name.toLowerCase().endsWith(".pdf") ? "application/pdf" : "application/octet-stream"

    const ok = await postDocument(cfg, data, name, mime)
    await alert(ok ? "✅ Queued" : "❌ Failed",
      ok ? `"${name}" sent to consume queue.\nProcessing takes a moment.`
         : "Check connection and try again.")
  } else {
    const images = await Photos.fromLibrary()
    if (!images?.length) return

    let failed = 0
    for (let i = 0; i < images.length; i++) {
      const imgData = Data.fromPNG(images[i])
      const name = `photo_${Date.now()}_${i}.png`
      if (!await postDocument(cfg, imgData, name, "image/png")) failed++
    }
    await alert(
      failed === 0 ? "✅ Queued" : `⚠️ ${failed} failed`,
      `${images.length - failed}/${images.length} image(s) sent to consume queue.`
    )
  }
}

async function showTags(cfg) {
  const data = await api(cfg, "tags/?page_size=100&ordering=name")
  if (!data?.results) return

  const paraFirst = ["project", "area", "resource", "archive", "inbox"]
  const sorted = [...data.results].sort((a, b) => {
    const ai = paraFirst.indexOf(a.name), bi = paraFirst.indexOf(b.name)
    if (ai >= 0 && bi >= 0) return ai - bi
    if (ai >= 0) return -1
    if (bi >= 0) return 1
    return a.name.localeCompare(b.name)
  })

  const t = new UITable()
  t.showSeparators = true
  const h = new UITableRow(); h.isHeader = true; h.addText("Browse by Tag"); t.addRow(h)

  for (const tag of sorted) {
    const r = new UITableRow(); r.height = 52
    r.addText(tag.name, `${tag.document_count} doc${tag.document_count !== 1 ? "s" : ""}`)
    r.onSelect = async () => showDocs(
      cfg,
      `documents/?tags__id__in=${tag.id}&ordering=-added&page_size=25`,
      tag.name
    )
    t.addRow(r)
  }

  await t.present()
}

async function showCorrespondents(cfg) {
  const data = await api(cfg, "correspondents/?page_size=100&ordering=name")
  if (!data?.results) return

  const t = new UITable()
  t.showSeparators = true
  const h = new UITableRow(); h.isHeader = true; h.addText("Correspondents"); t.addRow(h)

  for (const c of data.results) {
    const r = new UITableRow(); r.height = 52
    r.addText(c.name, `${c.document_count} docs`)
    r.onSelect = async () => showDocs(
      cfg,
      `documents/?correspondent__id=${c.id}&ordering=-added&page_size=25`,
      c.name
    )
    t.addRow(r)
  }

  await t.present()
}

async function showDocTypes(cfg) {
  const data = await api(cfg, "document_types/?page_size=100&ordering=name")
  if (!data?.results) return

  const t = new UITable()
  t.showSeparators = true
  const h = new UITableRow(); h.isHeader = true; h.addText("Document Types"); t.addRow(h)

  for (const dt of data.results) {
    const r = new UITableRow(); r.height = 52
    r.addText(dt.name, `${dt.document_count} docs`)
    r.onSelect = async () => showDocs(
      cfg,
      `documents/?document_type__id=${dt.id}&ordering=-added&page_size=25`,
      dt.name
    )
    t.addRow(r)
  }

  await t.present()
}

async function showSettings(cfg) {
  const a = new Alert()
  a.title = "Settings"
  a.message = `Server: ${cfg.url}\nToken:  ${cfg.token.slice(0, 10)}…`
  a.addAction("Change URL")
  a.addAction("Change Token")
  a.addDestructiveAction("Reset All")
  a.addCancelAction("Close")

  const choice = await a.presentAlert()
  if (choice === 0) {
    const b = new Alert(); b.title = "Server URL"
    b.addTextField("URL", cfg.url); b.addAction("Save"); b.addCancelAction("Cancel")
    if (await b.presentAlert() === 0) Keychain.set(KC_URL, b.textFieldValue(0).replace(/\/+$/, ""))
  } else if (choice === 1) {
    const b = new Alert(); b.title = "API Token"
    b.addSecureField("Token", ""); b.addAction("Save"); b.addCancelAction("Cancel")
    if (await b.presentAlert() === 0) Keychain.set(KC_TOKEN, b.textFieldValue(0).trim())
  } else if (choice === 2) {
    Keychain.remove(KC_URL); Keychain.remove(KC_TOKEN)
    await alert("Reset", "Credentials cleared. Restart to reconfigure.")
  }
}

// ── Main Menu ─────────────────────────────────────────

async function showMenu(cfg) {
  const items = [
    { icon: "🕐", title: "Recent",          sub: "Last 25 documents" },
    { icon: "📥", title: "Inbox",           sub: "Unprocessed items" },
    { icon: "🔍", title: "Search",          sub: "Full-text search" },
    { icon: "⬆️", title: "Upload",          sub: "Files or Photos" },
    { icon: "🏷", title: "Tags",            sub: "PARA categories + custom" },
    { icon: "👤", title: "Correspondents",  sub: "Browse by sender" },
    { icon: "📂", title: "Document Types",  sub: "Invoice, Contract, etc." },
    { icon: "🌐", title: "Web UI",          sub: cfg.url },
    { icon: "⚙️", title: "Settings",        sub: "Server & token" },
  ]

  const t = new UITable()
  t.showSeparators = true

  const hdr = new UITableRow()
  hdr.isHeader = true
  hdr.addText("📄 Paperless NGX")
  t.addRow(hdr)

  items.forEach((item, i) => {
    const r = new UITableRow(); r.height = 56
    const ico = r.addText(item.icon); ico.widthWeight = 12
    r.addText(item.title, item.sub)
    r.onSelect = async () => {
      switch (i) {
        case 0: await showDocs(cfg, "documents/?ordering=-added&page_size=25", "Recent"); break
        case 1: await showDocs(cfg, "documents/?is_tagged=false&ordering=-added&page_size=25", "Inbox"); break
        case 2: await showSearch(cfg); break
        case 3: await showUpload(cfg); break
        case 4: await showTags(cfg); break
        case 5: await showCorrespondents(cfg); break
        case 6: await showDocTypes(cfg); break
        case 7: Safari.open(cfg.url); break
        case 8: await showSettings(cfg); break
      }
    }
    t.addRow(r)
  })

  await t.present()
}

// ── Helpers ───────────────────────────────────────────

async function alert(title, msg) {
  const a = new Alert(); a.title = title; a.message = msg; a.addAction("OK")
  await a.presentAlert()
}

// ── Entry Point ───────────────────────────────────────

const cfg = await getConfig()

if (config.runsInWidget) {
  Script.setWidget(await buildWidget(cfg))
} else {
  await showMenu(cfg)
}

Script.complete()
