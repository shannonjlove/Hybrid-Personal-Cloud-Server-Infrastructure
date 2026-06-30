// memory-query.js
// Query and write to ai-memory from iOS.
// Can be run interactively or called from a Shortcut with input text.
//
// Shortcut usage:
//   "Run Script" action → memory-query.js
//   Pass text as input to store it as a memory.
//
// Requires: run 00-setup-keychain.js first.

const MEMORY_URL = Keychain.contains("memory.url")
  ? Keychain.get("memory.url")
  : "https://memory.shannonjlove.cloud";

async function memoryAPI(path, method = "GET", body = null) {
  const req = new Request(`${MEMORY_URL}${path}`);
  req.method = method;
  req.headers = { "Content-Type": "application/json" };
  if (body) req.body = JSON.stringify(body);
  return req.loadJSON();
}

// If called from Shortcut with text input, store it immediately
const input = args.plainTexts[0] || "";

if (input) {
  const result = await memoryAPI("/memories", "POST", {
    content: input,
    tier:    "mid",
  });
  const alert = new Alert();
  alert.title = result.id ? "Memory Saved" : "Error";
  alert.message = result.id ? `Stored (id: ${result.id})` : JSON.stringify(result);
  alert.addAction("OK");
  await alert.presentAlert();
  Script.complete();
} else {
  // Interactive mode — search or write
  const menu = new Alert();
  menu.title = "ai-memory";
  menu.message = MEMORY_URL;
  menu.addAction("🔍  Search memories");
  menu.addAction("✍️  Store a memory");
  menu.addAction("📋  Recent memories");
  menu.addCancelAction("Cancel");

  const choice = await menu.presentSheet();

  if (choice === 0) {
    // Search
    const searchAlert = new Alert();
    searchAlert.title = "Search Memories";
    searchAlert.addTextField("Query...");
    searchAlert.addAction("Search");
    searchAlert.addCancelAction("Cancel");
    await searchAlert.presentAlert();
    const query = searchAlert.textFieldValue(0).trim();
    if (!query) { Script.complete(); return; }

    const results = await memoryAPI(`/memories/search?q=${encodeURIComponent(query)}&limit=10`);
    const items = Array.isArray(results) ? results : (results.results || results.memories || []);

    const table = new UITable();
    table.showSeparators = true;
    for (const item of items) {
      const row = new UITableRow();
      row.height = 60;
      const text = item.content || item.text || JSON.stringify(item);
      const preview = text.length > 120 ? text.slice(0, 120) + "…" : text;
      const cell = row.addText(preview, `Tier: ${item.tier || "?"} · Score: ${item.score?.toFixed(2) ?? "?"}`);
      cell.titleFont = Font.systemFont(13);
      cell.subtitleColor = Color.gray();
      table.addRow(row);
    }
    if (items.length === 0) {
      const empty = new UITableRow();
      empty.addText("No results found.");
      table.addRow(empty);
    }
    await table.present();

  } else if (choice === 1) {
    // Store
    const writeAlert = new Alert();
    writeAlert.title = "Store a Memory";
    writeAlert.addTextField("What to remember...");
    writeAlert.addAction("Save (mid-term)");
    writeAlert.addAction("Save (long-term)");
    writeAlert.addCancelAction("Cancel");
    const tierChoice = await writeAlert.presentAlert();
    const content = writeAlert.textFieldValue(0).trim();
    if (!content || tierChoice === -1) { Script.complete(); return; }

    const tier = tierChoice === 0 ? "mid" : "long";
    const result = await memoryAPI("/memories", "POST", { content, tier });

    const done = new Alert();
    done.title = result.id ? "Saved" : "Error";
    done.message = result.id ? `Memory stored as ${tier}-term (id: ${result.id})` : JSON.stringify(result);
    done.addAction("OK");
    await done.presentAlert();

  } else if (choice === 2) {
    // Recent
    const results = await memoryAPI("/memories?limit=15&sort=recent");
    const items = Array.isArray(results) ? results : (results.results || results.memories || []);

    const table = new UITable();
    table.showSeparators = true;
    const hdr = new UITableRow();
    hdr.isHeader = true;
    hdr.addText("Recent Memories");
    table.addRow(hdr);

    for (const item of items) {
      const row = new UITableRow();
      row.height = 60;
      const text = item.content || item.text || JSON.stringify(item);
      const preview = text.length > 120 ? text.slice(0, 120) + "…" : text;
      const cell = row.addText(preview, `${item.tier || "?"} · ${item.created_at?.slice(0,10) ?? ""}`);
      cell.titleFont = Font.systemFont(13);
      cell.subtitleColor = Color.gray();
      table.addRow(row);
    }
    await table.present();
  }
}
