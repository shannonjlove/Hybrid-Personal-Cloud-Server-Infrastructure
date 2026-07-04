// PaperlessUpload — Quick-capture script for iOS Shortcuts
// ─────────────────────────────────────────────────────────
// Called from Shortcuts.app with a file or image as input.
// Can also be run standalone from Scriptable (shows file picker).
//
// SHORTCUTS INTEGRATION:
//   Shortcuts.app → New Shortcut:
//     [Scan Document]  or  [Select File]  or  [Take Photo]
//     → [Save to Files] (temp, if needed)
//     → [Run Script: PaperlessUpload]   (pass file as input)
//
// The shortcut can pass:
//   - A file via "Choose from Menu → Run Shortcut" with a file input
//   - Or just run this standalone and pick from Files/Photos

const KC_URL   = "paperless_ngx_url"
const KC_TOKEN = "paperless_ngx_token"

// ── Config ────────────────────────────────────────────

function cfg() {
  if (!Keychain.contains(KC_URL) || !Keychain.contains(KC_TOKEN)) {
    throw new Error(
      "Paperless not configured. Run the main Paperless.js script first to set up credentials."
    )
  }
  return { url: Keychain.get(KC_URL), token: Keychain.get(KC_TOKEN) }
}

// ── Upload ────────────────────────────────────────────

async function upload(fileData, filename, mimeType, config) {
  const req = new Request(`${config.url}/api/documents/post_document/`)
  req.method = "POST"
  req.headers = { "Authorization": `Token ${config.token}` }
  req.addFileDataToMultipart(fileData, mimeType, "document", filename)
  try {
    await req.load()
    return true
  } catch (e) {
    console.error(`Upload error: ${e}`)
    return false
  }
}

function mimeFor(filename) {
  const ext = filename.split(".").pop().toLowerCase()
  const map = {
    pdf:  "application/pdf",
    png:  "image/png",
    jpg:  "image/jpeg",
    jpeg: "image/jpeg",
    heic: "image/heic",
    tiff: "image/tiff",
    gif:  "image/gif",
    docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    txt:  "text/plain",
  }
  return map[ext] || "application/octet-stream"
}

// ── Entry Point ───────────────────────────────────────

let config
try { config = cfg() } catch (e) {
  const a = new Alert(); a.title = "Setup Required"; a.message = e.message; a.addAction("OK")
  await a.presentAlert(); Script.complete()
}

let succeeded = 0
let failed = 0

// ── Mode 1: Called from Shortcuts with file URLs ──────
if (args.fileURLs.length > 0) {
  const fm = FileManager.local()
  for (const url of args.fileURLs) {
    const data     = fm.readData(url)
    const filename = url.split("/").pop()
    const ok = await upload(data, filename, mimeFor(filename), config)
    ok ? succeeded++ : failed++
  }

// ── Mode 2: Called from Shortcuts with images ─────────
} else if (args.images.length > 0) {
  for (let i = 0; i < args.images.length; i++) {
    const imgData = Data.fromPNG(args.images[i])
    const filename = `scan_${Date.now()}_${i}.png`
    const ok = await upload(imgData, filename, "image/png", config)
    ok ? succeeded++ : failed++
  }

// ── Mode 3: Standalone — show picker ──────────────────
} else {
  const a = new Alert()
  a.title = "Upload to Paperless"
  a.addAction("📁  Files")
  a.addAction("🖼  Photos")
  a.addCancelAction("Cancel")

  const choice = await a.presentAlert()

  if (choice === 0) {
    const files = await DocumentPicker.openFile(["public.item"])
    if (files?.length) {
      const fm = FileManager.local()
      for (const f of files) {
        const data = fm.readData(f)
        const name = f.split("/").pop()
        const ok = await upload(data, name, mimeFor(name), config)
        ok ? succeeded++ : failed++
      }
    }
  } else if (choice === 1) {
    const images = await Photos.fromLibrary()
    if (images?.length) {
      for (let i = 0; i < images.length; i++) {
        const imgData = Data.fromPNG(images[i])
        const ok = await upload(imgData, `photo_${Date.now()}_${i}.png`, "image/png", config)
        ok ? succeeded++ : failed++
      }
    }
  }
}

// ── Result notification ───────────────────────────────

if (succeeded + failed > 0) {
  const a = new Alert()
  if (failed === 0) {
    a.title = "✅ Uploaded"
    a.message = `${succeeded} file${succeeded !== 1 ? "s" : ""} sent to Paperless consume queue.\nProcessing may take a moment.`
  } else {
    a.title = `⚠️ Partial (${succeeded}/${succeeded + failed})`
    a.message = `${failed} file${failed !== 1 ? "s" : ""} failed to upload. Check connection.`
  }
  a.addAction("OK")
  await a.presentAlert()
}

// Return result string to Shortcuts
Script.setShortcutOutput(
  succeeded > 0
    ? `Queued ${succeeded} file${succeeded !== 1 ? "s" : ""} for processing`
    : "No files uploaded"
)

Script.complete()
