// PaperlessWidget — Standalone home screen widget
// ─────────────────────────────────────────────────
// Supports: small, medium, large widget sizes
// Add as a Scriptable widget on your home screen.
// Tapping opens Paperless web UI.
//
// Credentials shared with Paperless.js via Keychain.

const KC_URL   = "paperless_ngx_url"
const KC_TOKEN = "paperless_ngx_token"

// ── Palette ───────────────────────────────────────────
const C = {
  bg:       new Color("#0d1117"),
  bgAlt:    new Color("#161b22"),
  accent:   new Color("#58a6ff"),
  text:     new Color("#c9d1d9"),
  muted:    new Color("#8b949e"),
  dim:      new Color("#484f58"),
  green:    new Color("#3fb950"),
  orange:   new Color("#f0883e"),
  red:      new Color("#f85149"),
}

// ── API ───────────────────────────────────────────────

async function load(endpoint) {
  if (!Keychain.contains(KC_URL) || !Keychain.contains(KC_TOKEN)) return null
  const req = new Request(`${Keychain.get(KC_URL)}/api/${endpoint}`)
  req.headers = { "Authorization": `Token ${Keychain.get(KC_TOKEN)}` }
  try { return await req.loadJSON() } catch { return null }
}

// ── Small Widget ──────────────────────────────────────

async function buildSmall() {
  const stats = await load("statistics/")
  const recent = await load("documents/?ordering=-added&page_size=1")

  const w = new ListWidget()
  w.backgroundColor = C.bg
  w.setPadding(14, 16, 14, 16)
  w.url = Keychain.get(KC_URL)

  const icon = w.addText("📄")
  icon.font = Font.systemFont(28)

  w.addSpacer(6)

  const title = w.addText("Paperless")
  title.font = Font.boldSystemFont(15)
  title.textColor = C.accent

  w.addSpacer(4)

  if (stats) {
    const total = w.addText(`${stats.documents_total}`)
    total.font = Font.boldRoundedSystemFont(32)
    total.textColor = C.text

    const label = w.addText("documents")
    label.font = Font.systemFont(11)
    label.textColor = C.muted

    w.addSpacer(6)

    if (stats.documents_inbox_count > 0) {
      const inbox = w.addText(`${stats.documents_inbox_count} in inbox`)
      inbox.font = Font.systemFont(10)
      inbox.textColor = C.orange
    }
  } else {
    const err = w.addText("Not configured")
    err.font = Font.systemFont(11)
    err.textColor = C.red
  }

  w.addSpacer()
  return w
}

// ── Medium Widget ─────────────────────────────────────

async function buildMedium() {
  const [stats, recent] = await Promise.all([
    load("statistics/"),
    load("documents/?ordering=-added&page_size=4"),
  ])

  const w = new ListWidget()
  w.backgroundColor = C.bg
  w.setPadding(12, 16, 12, 16)
  w.url = Keychain.get(KC_URL)

  // Header
  const hdr = w.addStack()
  hdr.layoutHorizontally()
  hdr.centerAlignContent()

  const hIcon = hdr.addText("📄")
  hIcon.font = Font.systemFont(13)
  hdr.addSpacer(6)

  const hTitle = hdr.addText("Paperless NGX")
  hTitle.font = Font.boldSystemFont(14)
  hTitle.textColor = C.accent
  hdr.addSpacer()

  if (stats) {
    const hCount = hdr.addText(`${stats.documents_total} total`)
    hCount.font = Font.systemFont(11)
    hCount.textColor = C.muted
  }

  w.addSpacer(8)

  const docs = recent?.results || []
  if (docs.length === 0) {
    const empty = w.addText("No documents yet")
    empty.font = Font.systemFont(12)
    empty.textColor = C.muted
  } else {
    for (const doc of docs) {
      const row = w.addStack()
      row.layoutHorizontally()
      row.centerAlignContent()

      const dot = row.addText("•")
      dot.font = Font.systemFont(10)
      dot.textColor = C.accent
      row.addSpacer(6)

      const docTitle = row.addText(
        doc.title.length > 38 ? doc.title.slice(0, 36) + "…" : doc.title
      )
      docTitle.font = Font.systemFont(11)
      docTitle.textColor = C.text
      docTitle.lineLimit = 1
      row.addSpacer()

      const date = row.addText(doc.created?.slice(0, 10) ?? "")
      date.font = Font.monospacedSystemFont(9, .regular)
      date.textColor = C.dim

      w.addSpacer(4)
    }
  }

  w.addSpacer()

  if (stats?.documents_inbox_count > 0) {
    const inboxRow = w.addStack()
    inboxRow.layoutHorizontally()
    const inboxDot = inboxRow.addText("●")
    inboxDot.font = Font.systemFont(8)
    inboxDot.textColor = C.orange
    inboxRow.addSpacer(5)
    const inboxTxt = inboxRow.addText(`${stats.documents_inbox_count} awaiting review`)
    inboxTxt.font = Font.systemFont(10)
    inboxTxt.textColor = C.orange
  }

  return w
}

// ── Large Widget ──────────────────────────────────────

async function buildLarge() {
  const [stats, recent, tags] = await Promise.all([
    load("statistics/"),
    load("documents/?ordering=-added&page_size=8"),
    load("tags/?page_size=6&ordering=-document_count"),
  ])

  const w = new ListWidget()
  w.backgroundColor = C.bg
  w.setPadding(14, 16, 14, 16)
  w.url = Keychain.get(KC_URL)

  // Header
  const hdr = w.addStack()
  hdr.layoutHorizontally()
  hdr.centerAlignContent()

  const hTitle = hdr.addText("📄  Paperless NGX")
  hTitle.font = Font.boldSystemFont(16)
  hTitle.textColor = C.accent
  hdr.addSpacer()

  if (stats) {
    const chip = hdr.addStack()
    chip.backgroundColor = C.bgAlt
    chip.cornerRadius = 8
    chip.setPadding(3, 8, 3, 8)
    const chipTxt = chip.addText(`${stats.documents_total}`)
    chipTxt.font = Font.boldSystemFont(12)
    chipTxt.textColor = C.text
  }

  w.addSpacer(10)

  // Stats row
  if (stats) {
    const statsRow = w.addStack()
    statsRow.layoutHorizontally()
    statsRow.spacing = 12

    const addStat = (label, value, color) => {
      const box = statsRow.addStack()
      box.layoutVertically()
      box.backgroundColor = C.bgAlt
      box.cornerRadius = 8
      box.setPadding(6, 10, 6, 10)
      const v = box.addText(`${value}`)
      v.font = Font.boldRoundedSystemFont(18)
      v.textColor = color
      const l = box.addText(label)
      l.font = Font.systemFont(9)
      l.textColor = C.muted
    }

    addStat("Total",  stats.documents_total,         C.text)
    statsRow.addSpacer()
    addStat("Inbox",  stats.documents_inbox_count,    C.orange)
    statsRow.addSpacer()
    addStat("Tagged", stats.documents_total - (stats.documents_inbox_count || 0), C.green)
  }

  w.addSpacer(10)

  // Recent docs
  const recentHdr = w.addText("RECENT")
  recentHdr.font = Font.boldSystemFont(9)
  recentHdr.textColor = C.dim

  w.addSpacer(4)

  const docs = recent?.results || []
  for (const doc of docs.slice(0, 6)) {
    const row = w.addStack()
    row.layoutHorizontally()
    row.centerAlignContent()

    const dot = row.addText("·")
    dot.font = Font.systemFont(11); dot.textColor = C.accent
    row.addSpacer(5)

    const t = row.addText(doc.title.length > 34 ? doc.title.slice(0, 32) + "…" : doc.title)
    t.font = Font.systemFont(11); t.textColor = C.text; t.lineLimit = 1
    row.addSpacer()

    const d = row.addText(doc.created?.slice(0, 10) ?? "")
    d.font = Font.monospacedSystemFont(9, .regular); d.textColor = C.dim

    w.addSpacer(3)
  }

  w.addSpacer()

  // Top tags
  if (tags?.results?.length) {
    const tagHdr = w.addText("TOP TAGS")
    tagHdr.font = Font.boldSystemFont(9); tagHdr.textColor = C.dim
    w.addSpacer(4)

    const tagRow = w.addStack()
    tagRow.layoutHorizontally()
    tagRow.spacing = 6
    for (const tag of tags.results.slice(0, 5)) {
      const chip = tagRow.addStack()
      chip.backgroundColor = C.bgAlt; chip.cornerRadius = 6
      chip.setPadding(3, 7, 3, 7)
      const ct = chip.addText(tag.name)
      ct.font = Font.systemFont(10); ct.textColor = C.accent
    }
  }

  return w
}

// ── Entry Point ───────────────────────────────────────

let widget
const family = config.widgetFamily

if (family === "small")  widget = await buildSmall()
else if (family === "large") widget = await buildLarge()
else                     widget = await buildMedium()

Script.setWidget(widget)
Script.complete()
