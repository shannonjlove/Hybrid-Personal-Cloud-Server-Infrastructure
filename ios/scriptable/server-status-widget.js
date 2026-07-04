// server-status-widget.js
// Home screen widget showing live status of your cloud services.
// Add as a Scriptable widget (small or medium size).
//
// Checks: NPM, ai-memory, and any URLs you add to SERVICES below.

const SERVICES = [
  { name: "NPM",    url: "https://npm.shannonjlove.cloud/api/" },
  { name: "Memory", url: "https://memory.shannonjlove.cloud/health" },
  { name: "Docs",   url: "https://docs.shannonjlove.cloud" },
  { name: "Photos", url: "https://photos.shannonjlove.cloud" },
];

const COLOR_UP   = new Color("#30d158");  // green
const COLOR_DOWN = new Color("#ff453a");  // red
const COLOR_BG   = new Color("#1c1c1e");
const COLOR_TEXT = Color.white();
const COLOR_DIM  = new Color("#8e8e93");

async function checkService(service) {
  try {
    const req = new Request(service.url);
    req.timeoutInterval = 5;
    req.method = "GET";
    await req.loadString();
    const code = req.response.statusCode;
    return { ...service, up: code < 500, code };
  } catch {
    return { ...service, up: false, code: 0 };
  }
}

const results = await Promise.all(SERVICES.map(checkService));
const allUp = results.every(r => r.up);
const upCount = results.filter(r => r.up).length;

// ---------------------------------------------------------------------------
// Widget layout
// ---------------------------------------------------------------------------
const widget = new ListWidget();
widget.backgroundColor = COLOR_BG;
widget.setPadding(12, 14, 12, 14);

// Title row
const titleStack = widget.addStack();
titleStack.layoutHorizontally();
titleStack.centerAlignContent();

const dot = titleStack.addText(allUp ? "●" : "●");
dot.font = Font.systemFont(10);
dot.textColor = allUp ? COLOR_UP : COLOR_DOWN;
titleStack.addSpacer(6);

const title = titleStack.addText("shannonjlove.cloud");
title.font = Font.boldSystemFont(13);
title.textColor = COLOR_TEXT;
titleStack.addSpacer();

const summary = titleStack.addText(`${upCount}/${results.length}`);
summary.font = Font.mediumSystemFont(12);
summary.textColor = upCount === results.length ? COLOR_UP : COLOR_DOWN;

widget.addSpacer(8);

// Service rows
for (const svc of results) {
  const row = widget.addStack();
  row.layoutHorizontally();
  row.centerAlignContent();

  const statusDot = row.addText("●");
  statusDot.font = Font.systemFont(9);
  statusDot.textColor = svc.up ? COLOR_UP : COLOR_DOWN;
  row.addSpacer(6);

  const name = row.addText(svc.name);
  name.font = Font.systemFont(12);
  name.textColor = COLOR_TEXT;
  row.addSpacer();

  const status = row.addText(svc.up ? "up" : `${svc.code || "down"}`);
  status.font = Font.systemFont(11);
  status.textColor = svc.up ? COLOR_DIM : COLOR_DOWN;

  widget.addSpacer(4);
}

widget.addSpacer();

// Timestamp
const ts = widget.addText(`Updated ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`);
ts.font = Font.systemFont(9);
ts.textColor = COLOR_DIM;
ts.rightAlignText();

// Refresh every 5 minutes
widget.refreshAfterDate = new Date(Date.now() + 5 * 60 * 1000);

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  await widget.presentSmall();
}
Script.complete();
